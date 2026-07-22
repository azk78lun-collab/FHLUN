import argparse
import base64
import contextlib
import importlib.util
import io
import json
import subprocess
import tempfile
import unittest
from pathlib import Path
from unittest import mock


MODULE_PATH = Path(__file__).resolve().parents[1] / "lun_agent.py"
SPEC = importlib.util.spec_from_file_location("lun_agent", MODULE_PATH)
lun_agent = importlib.util.module_from_spec(SPEC)
assert SPEC.loader
SPEC.loader.exec_module(lun_agent)


class AgentTestCase(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.root = Path(self.temp.name) / "lun"
        self.root.mkdir()
        (self.root / "uuid").write_text("11111111-1111-4111-8111-111111111111\n", encoding="utf-8")
        (self.root / "subtoken.log").write_text("legacy-token\n", encoding="utf-8")
        self.agent = lun_agent.Agent(self.root)
        args = argparse.Namespace(
            legacy_uuid=None,
            legacy_token=None,
            bind="127.0.0.1",
            port=31000,
            public_port=31000,
            legacy_http_port=0,
            legacy_http_public_port=0,
            scheme="http",
            public_host="example.com",
            certificate=None,
            private_key=None,
            xray_api="127.0.0.1:10085",
            singbox_api="127.0.0.1:10086",
            poll_interval=30,
            ss_port=32000,
            ss_public_port=32000,
            ss_server_password="AAAAAAAAAAAAAAAAAAAAAA==",
        )
        self.agent.initialize(args)

    def tearDown(self):
        self.agent.close()
        self.temp.cleanup()

    def add_user(self, name="alice"):
        return self.agent.add_user(argparse.Namespace(
            name=name,
            lifetime_quota="10G",
            monthly_quota="1G",
            reset_day=15,
            expires="never",
            max_devices=3,
            device_name="phone",
        ))

    def test_init_imports_legacy_identity(self):
        user = self.agent.db.connection.execute("SELECT * FROM users WHERE name='legacy-admin'").fetchone()
        device = self.agent.db.connection.execute("SELECT * FROM devices WHERE user_id=?", (user["id"],)).fetchone()
        self.assertEqual(device["uuid"], "11111111-1111-4111-8111-111111111111")
        self.assertEqual(device["token"], "legacy-token")
        self.assertEqual(device["legacy"], 1)

    def test_user_device_and_permissions(self):
        device = self.add_user()
        self.assertNotEqual(device["uuid"], device["password"])
        self.assertGreaterEqual(len(device["token"]), 32)
        self.agent.set_protocol(device["user_id"], "hy", False)
        permissions = self.agent.device_permissions(device["user_id"])
        self.assertFalse(permissions["hy"])
        second = self.agent.add_device(device["user_id"], "laptop")
        self.assertNotEqual(device["uuid"], second["uuid"])

    def test_device_disable_rotate_and_hard_delete(self):
        device = self.add_user()
        old_uuid = device["uuid"]
        old_token = device["token"]
        generated = self.agent.generated / old_token
        generated.mkdir(parents=True)
        self.agent.update_device(device["id"], enabled=False)
        self.assertNotIn(device["id"], {item["id"] for item in self.agent.active_devices()})
        self.agent.update_device(device["id"], name="phone-new", enabled=True)
        rotated = self.agent.rotate_device(device["id"], "phone-new")
        self.assertNotEqual(rotated["uuid"], old_uuid)
        self.assertNotEqual(rotated["token"], old_token)
        self.assertFalse(generated.exists())
        self.agent.delete_device(rotated["id"], "phone-new")
        self.assertIsNone(self.agent.db.connection.execute("SELECT 1 FROM devices WHERE id=?", (rotated["id"],)).fetchone())
        self.assertEqual(len(list(self.agent.backups.glob("db-*.sqlite3"))), 1)

    def test_database_backup_can_restore_previous_state(self):
        self.add_user("alice")
        snapshot = self.agent.backup_database()
        self.add_user("bob")
        self.assertIsNotNone(self.agent.db.connection.execute("SELECT 1 FROM users WHERE name='bob'").fetchone())
        self.agent.restore_database(str(snapshot))
        self.assertIsNone(self.agent.db.connection.execute("SELECT 1 FROM users WHERE name='bob'").fetchone())

    def test_apply_restores_core_config_when_restart_fails(self):
        current = self.root / "xr.json"
        previous = self.agent.generated / "previous-xr.json"
        current.write_text('{"state":"new"}\n', encoding="utf-8")
        previous.write_text('{"state":"old"}\n', encoding="utf-8")
        with mock.patch.object(self.agent, "reconcile", return_value={"xray": True, "singbox": False}), \
             mock.patch.object(
                 self.agent,
                 "restart_cores",
                 side_effect=[lun_agent.AgentError("restart failed"), None],
             ):
            with self.assertRaises(lun_agent.AgentError):
                self.agent.apply()
        self.assertEqual(json.loads(current.read_text(encoding="utf-8"))["state"], "old")

    def test_systemd_restart_clears_start_limit_first(self):
        calls = []
        with mock.patch.object(lun_agent.Path, "exists", return_value=True), \
             mock.patch.object(lun_agent.shutil, "which", return_value="/usr/bin/systemctl"), \
             mock.patch.object(self.agent, "_run", side_effect=lambda command, **kwargs: calls.append((command, kwargs))):
            self.agent.restart_cores({"xray": True, "singbox": True})
        self.assertEqual([item[0] for item in calls], [
            ["systemctl", "reset-failed", "xr"],
            ["systemctl", "restart", "xr"],
            ["systemctl", "reset-failed", "sb"],
            ["systemctl", "restart", "sb"],
        ])
        self.assertFalse(calls[0][1]["check"])
        self.assertFalse(calls[2][1]["check"])

    def test_quota_disables_user(self):
        device = self.add_user()
        period = self.agent.month_period(15)
        self.agent.db.connection.execute(
            "INSERT INTO usage_totals(device_id,core,uplink,downlink,month_uplink,month_downlink,period_start,updated_at) "
            "VALUES(?,?,?,?,?,?,?,?)",
            (device["id"], "xray", 0, 0, 1024 ** 3, 0, period, lun_agent.utc_now()),
        )
        self.agent.db.connection.commit()
        user = self.agent.db.connection.execute("SELECT * FROM users WHERE id=?", (device["user_id"],)).fetchone()
        active, reason = self.agent.effective_user(user)
        self.assertFalse(active)
        self.assertIn("本月", reason)

    def test_status_table_uses_monthly_gib_only(self):
        device = self.add_user()
        self.agent.db.connection.execute(
            "UPDATE users SET monthly_quota=? WHERE id=?", (1024 ** 3, device["user_id"])
        )
        self.agent.db.connection.commit()
        output = io.StringIO()
        with contextlib.redirect_stdout(output):
            lun_agent.print_status_table(self.agent.status_rows())
        rendered = output.getvalue()
        self.assertIn("已用/月额度", rendered)
        self.assertIn("0.00G/1.00G", rendered)
        self.assertNotIn("总用量", rendered)
        self.assertNotIn("/配额", rendered)

    def test_xray_reconcile_adds_users_stats_and_guards(self):
        device = self.add_user()
        data = {
            "inbounds": [{
                "tag": "reality-vision", "protocol": "vless",
                "settings": {"clients": [{"id": "11111111-1111-4111-8111-111111111111", "flow": "xtls-rprx-vision"}]},
            }],
            "outbounds": [{"tag": "direct", "protocol": "freedom"}],
            "routing": {"rules": []},
        }
        updated = self.agent._reconcile_xray(data, self.agent.active_devices(), self.agent.load_config())
        clients = updated["inbounds"][0]["settings"]["clients"]
        self.assertEqual(len(clients), 2)
        self.assertIn(device["uuid"], {item["id"] for item in clients})
        self.assertTrue(all("email" in item for item in clients))
        self.assertEqual(updated["api"]["listen"], "127.0.0.1:10085")
        self.assertEqual(updated["routing"]["rules"][2]["port"], "25")
        second = self.agent._reconcile_xray(updated, self.agent.active_devices(), self.agent.load_config())
        self.assertEqual(updated, second)

    def test_singbox_parallel_ss_and_idempotent_guards(self):
        self.add_user()
        data = {
            "inbounds": [
                {"type": "shadowsocks", "tag": "ss-2022", "listen_port": 20000,
                 "method": "2022-blake3-aes-128-gcm", "password": "legacy"},
                {"type": "hysteria2", "tag": "hy2-sb", "listen_port": 20001,
                 "users": [{"password": "old"}]},
            ],
            "route": {"rules": []},
        }
        first = self.agent._reconcile_singbox(data, self.agent.active_devices(), self.agent.load_config())
        second = self.agent._reconcile_singbox(first, self.agent.active_devices(), self.agent.load_config())
        tags = [item["tag"] for item in second["inbounds"]]
        self.assertEqual(tags.count("ss-2022-mu"), 1)
        self.assertEqual(len(second["route"]["rules"]), 3)
        legacy = next(item for item in second["inbounds"] if item["tag"] == "ss-2022")
        self.assertEqual(legacy["password"], "legacy")

    def test_subscription_preserves_server_path_and_rewrites_identity(self):
        device = self.add_user()
        old = "11111111-1111-4111-8111-111111111111"
        source = f"vless://{old}@example.com:443?type=xhttp&path={old}-xc#vless-xhttp-tls-tcp-test\n"
        rendered = self.agent.render_generic(source, device, self.agent.device_permissions(device["user_id"]), self.agent.load_config())
        self.assertIn(f"vless://{device['uuid']}@", rendered)
        self.assertIn(f"path={old}-xc", rendered)

    def test_shadowsocks_subscription_uses_parallel_credentials(self):
        device = self.add_user()
        payload = "2022-blake3-aes-128-gcm:legacy@example.com:20000"
        source = "ss://" + base64.b64encode(payload.encode()).decode() + "#Shadowsocks-2022-test\n"
        rendered = self.agent.render_generic(source, device, self.agent.device_permissions(device["user_id"]), self.agent.load_config())
        encoded = rendered.split("://", 1)[1].split("#", 1)[0]
        decoded = base64.b64decode(encoded).decode()
        self.assertIn(self.agent.load_config()["ss_server_password"], decoded)
        self.assertIn(device["ss_password"], decoded)
        self.assertTrue(decoded.endswith(":32000"))

    def test_hard_delete_revokes_token_and_replaces_backups(self):
        device = self.add_user()
        generated = self.agent.generated / device["token"]
        generated.mkdir(parents=True)
        (generated / "jhsub.txt").write_text("credential", encoding="utf-8")
        user = self.agent.db.connection.execute("SELECT * FROM users WHERE id=?", (device["user_id"],)).fetchone()
        self.agent.delete_user(user["id"], user["name"])
        found, active, _ = self.agent.find_device_by_token(device["token"])
        self.assertIsNone(found)
        self.assertFalse(active)
        self.assertFalse(generated.exists())
        self.assertEqual(len(list(self.agent.backups.glob("db-*.sqlite3"))), 1)

    def test_xray_stats_are_added_to_lifetime_and_month(self):
        device = self.add_user()
        identity = f"lun:u:{device['user_id']}:d:{device['id']}"
        (self.root / "xray").write_text("placeholder", encoding="utf-8")
        payload = json.dumps({"stat": [
            {"name": f"user>>>{identity}>>>traffic>>>uplink", "value": 100},
            {"name": f"user>>>{device['uuid']}>>>traffic>>>downlink", "value": 250},
        ]})
        completed = subprocess.CompletedProcess([], 0, payload, "")
        with mock.patch.object(self.agent, "_run", return_value=completed):
            sampled = self.agent.sample_core_stats("xray", "127.0.0.1:10085")
        self.assertEqual(sampled, 350)
        lifetime, monthly = self.agent.usage_for_user(device["user_id"])
        self.assertEqual(lifetime, 350)
        self.assertEqual(monthly, 350)

    def test_singbox_helper_stats_are_added_to_usage(self):
        device = self.add_user()
        identity = f"lun:u:{device['user_id']}:d:{device['id']}"
        helper = self.root / "modules" / "multiuser" / "lun-sb-stats"
        helper.parent.mkdir(parents=True, exist_ok=True)
        helper.write_text("placeholder", encoding="utf-8")
        payload = json.dumps({"stats": [
            {"name": f"user>>>{identity}>>>traffic>>>uplink", "value": 40},
            {"name": f"user>>>{identity}>>>traffic>>>downlink", "value": 60},
        ]})
        completed = subprocess.CompletedProcess([], 0, payload, "")
        with mock.patch.object(self.agent, "_run", return_value=completed):
            sampled = self.agent.sample_core_stats("singbox", "127.0.0.1:10086")
        self.assertEqual(sampled, 100)
        lifetime, monthly = self.agent.usage_for_user(device["user_id"])
        self.assertEqual(lifetime, 100)
        self.assertEqual(monthly, 100)

    def test_protocol_disable_removes_generic_node(self):
        device = self.add_user()
        self.agent.set_protocol(device["user_id"], "hy", False)
        source = "hysteria2://old@example.com:443#hysteria2-test\nanytls://old@example.com:443#anytls-test\n"
        rendered = self.agent.render_generic(
            source, device, self.agent.device_permissions(device["user_id"]), self.agent.load_config()
        )
        self.assertNotIn("hysteria2", rendered)
        self.assertIn("anytls", rendered)


if __name__ == "__main__":
    unittest.main()
