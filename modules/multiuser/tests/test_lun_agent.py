import argparse
import base64
import contextlib
import importlib.util
import io
import json
import os
import sqlite3
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

    def add_cluster_subscription(self, token="cluster-token-123456", filename="jhsub.txt", payload=b"cached-cluster"):
        database = self.root / "modules" / "cluster" / "data" / "cluster.db"
        database.parent.mkdir(parents=True, exist_ok=True)
        connection = sqlite3.connect(database)
        try:
            connection.execute("CREATE TABLE profiles (token TEXT, enabled INTEGER)")
            connection.execute("INSERT INTO profiles VALUES (?, 1)", (token,))
            connection.commit()
        finally:
            connection.close()
        target = self.root / "modules" / "cluster" / "generated" / token / filename
        target.parent.mkdir(parents=True, exist_ok=True)
        target.write_bytes(payload)
        return token, filename, payload

    def add_cluster_script(self):
        script = self.root / "modules" / "cluster" / "lun_cluster.py"
        script.parent.mkdir(parents=True, exist_ok=True)
        script.write_text("# test stub\n", encoding="utf-8")
        return script

    def serve_subscription(self, token, filename, send_body=True):
        class Response:
            def __init__(self, agent):
                self.server = type("Server", (), {"agent": agent, "legacy_only": False})()
                self.path = f"/{token}/{filename}"
                self.wfile = io.BytesIO()
                self.status = None
                self.headers = []

            def send_response(self, status):
                self.status = status

            def send_header(self, key, value):
                self.headers.append((key, value))

            def end_headers(self):
                pass

            def send_error(self, status, *_args):
                self.status = status

        response = Response(self.agent)
        lun_agent.SubscriptionHandler._serve_subscription(response, send_body)
        return response

    def test_init_imports_legacy_identity(self):
        user = self.agent.db.connection.execute("SELECT * FROM users WHERE name='legacy-admin'").fetchone()
        device = self.agent.db.connection.execute("SELECT * FROM devices WHERE user_id=?", (user["id"],)).fetchone()
        self.assertEqual(device["uuid"], "11111111-1111-4111-8111-111111111111")
        self.assertEqual(device["token"], "legacy-token")
        self.assertEqual(device["legacy"], 1)

    def test_visit_init_without_multiuser_config_is_reused_by_later_init(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory) / "lun"
            root.mkdir()
            (root / "uuid").write_text(
                "22222222-2222-4222-8222-222222222222\n", encoding="utf-8"
            )
            agent = lun_agent.Agent(root)
            try:
                result = agent.initialize_visit()
                self.assertFalse(agent.config_path.exists())
                self.assertEqual(result["device_id"], 1)
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
                    ss_port=0,
                    ss_public_port=0,
                    ss_server_password="AAAAAAAAAAAAAAAAAAAAAA==",
                )
                agent.initialize(args)
                self.assertEqual(
                    agent.db.connection.execute("SELECT COUNT(*) FROM users").fetchone()[0],
                    1,
                )
                self.assertEqual(
                    agent.db.connection.execute("SELECT COUNT(*) FROM devices").fetchone()[0],
                    1,
                )
            finally:
                agent.close()

    def test_visit_init_reuses_legacy_device_when_root_uuid_changed(self):
        legacy = self.agent.db.connection.execute(
            "SELECT * FROM devices WHERE legacy=1"
        ).fetchone()
        (self.root / "uuid").write_text(
            "33333333-3333-4333-8333-333333333333\n", encoding="utf-8"
        )
        result = self.agent.initialize_visit()
        self.assertEqual(result["device_id"], legacy["id"])
        self.assertEqual(result["uuid"], legacy["uuid"])
        self.assertEqual(
            self.agent.db.connection.execute("SELECT COUNT(*) FROM devices").fetchone()[0],
            1,
        )

    def test_user_device_and_permissions(self):
        device = self.add_user()
        self.assertNotEqual(device["uuid"], device["password"])
        self.assertGreaterEqual(len(device["token"]), 32)
        self.agent.set_protocol(device["user_id"], "hy", False)
        permissions = self.agent.device_permissions(device["user_id"])
        self.assertFalse(permissions["hy"])
        second = self.agent.add_device(device["user_id"], "laptop")
        self.assertNotEqual(device["uuid"], second["uuid"])

    def test_cluster_users_are_idempotent_and_read_only_on_child(self):
        source = self.add_user("central-user")
        bundle = self.agent.export_cluster_users([source["user_id"]])
        origin = "a" * 32
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory) / "lun"
            root.mkdir()
            (root / "uuid").write_text(
                "22222222-2222-4222-8222-222222222222\n", encoding="utf-8"
            )
            (root / "subtoken.log").write_text("child-legacy-token\n", encoding="utf-8")
            child = lun_agent.Agent(root)
            args = argparse.Namespace(
                legacy_uuid=None, legacy_token=None, bind="127.0.0.1", port=31001,
                public_port=31001, legacy_http_port=0, legacy_http_public_port=0,
                scheme="http", public_host="child.example.com", certificate=None,
                private_key=None, xray_api="127.0.0.1:10185",
                singbox_api="127.0.0.1:10186", poll_interval=30, ss_port=0,
                ss_public_port=0, ss_server_password="BBBBBBBBBBBBBBBBBBBBBB==",
            )
            child.initialize(args)
            try:
                first = child.import_cluster_users(bundle, origin)
                second = child.import_cluster_users(bundle, origin)
                self.assertEqual(first, second)
                managed = child.db.connection.execute(
                    "SELECT * FROM users WHERE cluster_managed=1"
                ).fetchone()
                device = child.db.connection.execute(
                    "SELECT * FROM devices WHERE user_id=?", (managed["id"],)
                ).fetchone()
                self.assertEqual(device["uuid"], source["uuid"])
                self.assertEqual(device["token"], source["token"])
                with self.assertRaisesRegex(lun_agent.AgentError, "主 VPS"):
                    child.add_device(managed["id"], "blocked")
                self.assertEqual(child.export_cluster_users()["users"][0]["name"], "legacy-admin")
                child.import_cluster_users({"schema_version": 1, "users": []}, origin)
                self.assertIsNone(child.db.connection.execute(
                    "SELECT 1 FROM users WHERE cluster_managed=1"
                ).fetchone())
            finally:
                child.close()

    def test_cluster_device_stable_key_survives_deleting_an_earlier_device(self):
        first = self.add_user("stable-user")
        second = self.agent.add_device(first["user_id"], "second")
        bundle = self.agent.export_cluster_users([first["user_id"]])
        self.assertEqual(
            [device["key"] for device in bundle["users"][0]["devices"]],
            [first["uuid"], second["uuid"]],
        )
        origin = "b" * 32
        with tempfile.TemporaryDirectory() as directory:
            child = lun_agent.Agent(Path(directory) / "lun")
            try:
                child.import_cluster_users(bundle, origin)
                before = child.db.connection.execute(
                    "SELECT id,uuid,token FROM devices WHERE uuid=?", (second["uuid"],)
                ).fetchone()
                reduced = json.loads(json.dumps(bundle))
                reduced["users"][0]["devices"] = [reduced["users"][0]["devices"][1]]
                child.import_cluster_users(reduced, origin)
                remaining = child.db.connection.execute(
                    "SELECT id,uuid,token FROM devices WHERE cluster_key LIKE ?",
                    (f"{origin}:user:%",),
                ).fetchall()
                self.assertEqual(len(remaining), 1)
                self.assertEqual(dict(remaining[0]), dict(before))
            finally:
                child.close()

    def test_cluster_device_keys_reject_duplicates_and_unsafe_values(self):
        first = self.add_user("validated-user")
        self.agent.add_device(first["user_id"], "second")
        bundle = self.agent.export_cluster_users([first["user_id"]])
        duplicate = json.loads(json.dumps(bundle))
        duplicate["users"][0]["devices"][1]["key"] = duplicate["users"][0]["devices"][0]["key"]
        with self.assertRaisesRegex(lun_agent.AgentError, "重复"):
            self.agent._validate_cluster_bundle(duplicate, "c" * 32)

        for unsafe in ("../device", "device/key", "device\\key", "\x00device", "-device", "x" * 129):
            invalid = json.loads(json.dumps(bundle))
            invalid["users"][0]["devices"][0]["key"] = unsafe
            with self.subTest(key=repr(unsafe)), self.assertRaisesRegex(lun_agent.AgentError, "稳定标识"):
                self.agent._validate_cluster_bundle(invalid, "c" * 32)

    def test_cluster_schema_v1_bundle_without_device_keys_uses_legacy_indexes(self):
        first = self.add_user("legacy-bundle-user")
        self.agent.add_device(first["user_id"], "second")
        bundle = self.agent.export_cluster_users([first["user_id"]])
        for device in bundle["users"][0]["devices"]:
            device.pop("key")
        checked = self.agent._validate_cluster_bundle(bundle, "d" * 32)
        self.assertEqual([device["key"] for device in checked[0]["devices"]], ["0", "1"])

    def test_cluster_stable_keys_migrate_existing_index_identity(self):
        source = self.add_user("migration-user")
        stable = self.agent.export_cluster_users([source["user_id"]])
        legacy = json.loads(json.dumps(stable))
        legacy["users"][0]["devices"][0].pop("key")
        origin = "e" * 32
        with tempfile.TemporaryDirectory() as directory:
            child = lun_agent.Agent(Path(directory) / "lun")
            try:
                child.import_cluster_users(legacy, origin)
                before = child.db.connection.execute(
                    "SELECT id,uuid,token FROM devices WHERE cluster_key=?",
                    (f"{origin}:user:{stable['users'][0]['key']}:device:0",),
                ).fetchone()
                child.import_cluster_users(stable, origin)
                after = child.db.connection.execute(
                    "SELECT id,uuid,token,cluster_key FROM devices WHERE id=?", (before["id"],)
                ).fetchone()
                self.assertEqual(after["id"], before["id"])
                self.assertEqual(after["uuid"], before["uuid"])
                self.assertEqual(after["token"], before["token"])
                self.assertTrue(after["cluster_key"].endswith(f":device:{source['uuid']}"))
            finally:
                child.close()

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

    def test_apply_visit_restores_core_config_when_restart_fails(self):
        self.agent.config_path.unlink()
        current = self.root / "xr.json"
        previous = self.agent.generated / "previous-visit-xr.json"
        current.write_text('{"state":"new"}\n', encoding="utf-8")
        previous.write_text('{"state":"old"}\n', encoding="utf-8")
        with mock.patch.object(
            self.agent,
            "reconcile_visit",
            return_value={"xray": True, "singbox": False},
        ), mock.patch.object(
            self.agent,
            "restart_cores",
            side_effect=[lun_agent.AgentError("restart failed"), None],
        ):
            with self.assertRaises(lun_agent.AgentError):
                self.agent.apply_visit()
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

    def test_visit_monitor_is_opt_in_and_controls_core_logs(self):
        self.assertFalse(self.agent.visit_monitor_settings()["enabled"])
        self.agent.set_visit_monitor(True, 7, 30)
        xray = self.agent._reconcile_xray(
            {
                "log": {"access": "/var/log/xray/original.log", "error": "/var/log/xray/error.log"},
                "inbounds": [], "outbounds": [], "routing": {"rules": []},
            },
            self.agent.active_devices(),
            self.agent.load_config(),
        )
        singbox = self.agent._reconcile_singbox(
            {
                "log": {
                    "disabled": True,
                    "level": "warn",
                    "output": "/var/log/sing-box/original.log",
                    "timestamp": False,
                },
                "inbounds": [], "route": {"rules": []},
            },
            self.agent.active_devices(),
            self.agent.load_config(),
        )
        self.assertEqual(xray["log"]["access"], str(self.agent.visit_log_paths()["xray"]))
        self.assertEqual(xray["log"]["loglevel"], "warning")
        self.assertEqual(singbox["log"]["output"], str(self.agent.visit_log_paths()["singbox"]))
        self.agent.set_visit_monitor(False, 7, 30)
        xray = self.agent._reconcile_xray(xray, self.agent.active_devices(), self.agent.load_config())
        singbox = self.agent._reconcile_singbox(singbox, self.agent.active_devices(), self.agent.load_config())
        self.assertEqual(xray["log"]["access"], "/var/log/xray/original.log")
        self.assertEqual(xray["log"]["error"], "/var/log/xray/error.log")
        self.assertEqual(singbox["log"]["output"], "/var/log/sing-box/original.log")
        self.assertTrue(singbox["log"]["disabled"])
        self.assertEqual(singbox["log"]["level"], "warn")
        self.assertFalse(singbox["log"]["timestamp"])

    def test_standalone_visit_fields_are_added_and_restored(self):
        self.agent.config_path.unlink()
        self.agent.set_visit_monitor(True, 7, 30)
        xray_original = {
            "log": {"loglevel": "none"},
            "inbounds": [{
                "tag": "reality-vision",
                "protocol": "vless",
                "settings": {
                    "clients": [{
                        "id": "11111111-1111-4111-8111-111111111111",
                        "flow": "xtls-rprx-vision",
                    }]
                },
            }],
        }
        singbox_original = {
            "log": {"disabled": False, "level": "info", "timestamp": True},
            "inbounds": [{
                "type": "hysteria2",
                "tag": "hy2-sb",
                "users": [{"password": "11111111-1111-4111-8111-111111111111"}],
            }],
            "route": {"rules": []},
        }
        devices = self.agent.active_devices()
        xray = self.agent._reconcile_visit_xray(
            json.loads(json.dumps(xray_original)), devices
        )
        singbox = self.agent._reconcile_visit_singbox(
            json.loads(json.dumps(singbox_original)), devices
        )
        identity = "lun:u:1:d:1"
        self.assertEqual(
            xray["inbounds"][0]["settings"]["clients"][0]["email"], identity
        )
        self.assertTrue(xray["inbounds"][0]["sniffing"]["enabled"])
        self.assertEqual(singbox["inbounds"][0]["users"][0]["name"], identity)
        self.assertEqual(singbox["route"]["rules"][0], {"action": "sniff"})
        self.agent.set_visit_monitor(False, 7, 30)
        restored_xray = self.agent._reconcile_visit_xray(xray, devices)
        restored_singbox = self.agent._reconcile_visit_singbox(singbox, devices)
        self.assertEqual(restored_xray, xray_original)
        self.assertEqual(restored_singbox, singbox_original)

    def test_visit_reconcile_validation_failure_keeps_config_and_settings(self):
        self.agent.config_path.unlink()
        self.agent.set_visit_monitor(True, 7, 30)
        target = self.root / "xr.json"
        original = {
            "log": {"loglevel": "none"},
            "inbounds": [{
                "tag": "reality-vision",
                "protocol": "vless",
                "settings": {
                    "clients": [{
                        "id": "11111111-1111-4111-8111-111111111111"
                    }]
                },
            }],
        }
        target.write_text(json.dumps(original), encoding="utf-8")
        with mock.patch.object(
            self.agent, "_validate_core", side_effect=lun_agent.AgentError("invalid")
        ):
            with self.assertRaises(lun_agent.AgentError):
                self.agent.reconcile_visit()
        self.assertEqual(json.loads(target.read_text(encoding="utf-8")), original)
        self.assertEqual(
            self.agent.db.setting("visit_xray_identity_before", ""), ""
        )
        self.assertEqual(
            self.agent.db.setting("visit_xray_log_fields_before", ""), ""
        )

    def test_visit_log_parsers_keep_domains_and_drop_ips(self):
        identity = "lun:u:2:d:3"
        xray = lun_agent.Agent.parse_visit_line(
            "xray",
            "2026/07/30 12:00:00 from tcp:1.2.3.4:5000 accepted "
            f"tcp:www.example.com:443 [reality-vision -> direct] email: {identity}",
        )
        self.assertEqual(xray["domain"], "www.example.com")
        self.assertEqual(xray["identity"], identity)
        self.assertEqual(xray["inbound"], "reality-vision")
        expected = int(lun_agent.dt.datetime(
            2026, 7, 30, 12, 0, 0,
            tzinfo=lun_agent.dt.datetime.now().astimezone().tzinfo,
        ).timestamp())
        self.assertEqual(xray["occurred_at"], expected)
        singbox = lun_agent.Agent.parse_visit_line(
            "singbox",
            "+0000 2026-07-30 12:00:01.250 INFO [123456 0ms] inbound/hysteria2[hy2-sb]: "
            f"[{identity}] inbound packet connection to video.example.net:443",
        )
        self.assertEqual(singbox["domain"], "video.example.net")
        self.assertEqual(singbox["network"], "udp")
        self.assertEqual(
            singbox["occurred_at"],
            int(lun_agent.dt.datetime(2026, 7, 30, 12, 0, 1, tzinfo=lun_agent.dt.timezone.utc).timestamp()),
        )
        without_timestamp = lun_agent.Agent.parse_visit_line(
            "xray",
            "accepted tcp:fallback.example.com:443 "
            f"[reality-vision -> direct] email: {identity}",
        )
        self.assertIsNone(without_timestamp["occurred_at"])
        self.assertIsNone(lun_agent.Agent.parse_visit_line(
            "xray",
            "from tcp:1.2.3.4:5000 accepted tcp:8.8.8.8:443 "
            f"[reality-vision -> direct] email: {identity}",
        ))

    def test_visit_logs_are_incremental_aggregated_and_clearable(self):
        device = self.add_user()
        identity = f"lun:u:{device['user_id']}:d:{device['id']}"
        self.agent.set_visit_monitor(True, 7, 30)
        paths = self.agent.visit_log_paths()
        current = lun_agent.dt.datetime.now().astimezone()
        first = current.strftime("%Y/%m/%d %H:%M:%S")
        second = (current + lun_agent.dt.timedelta(seconds=1)).strftime("%Y/%m/%d %H:%M:%S")
        paths["xray"].write_text(
            f"{first} from tcp:1.2.3.4:5000 accepted "
            f"tcp:www.example.com:443 [reality-vision -> direct] email: {identity}\n"
            f"{second} from tcp:1.2.3.4:5001 accepted "
            "tcp:ignored.example:443 [reality-vision -> direct] email: unknown\n",
            encoding="utf-8",
        )
        paths["singbox"].write_text(
            "INFO [123456 0ms] inbound/hysteria2[hy2-sb]: "
            f"[{identity}] inbound packet connection to video.example.net:443\n",
            encoding="utf-8",
        )
        self.assertEqual(self.agent.collect_visit_logs(), 2)
        self.assertEqual(self.agent.collect_visit_logs(), 0)
        recent = self.agent.visit_recent(1, 20, user_id=device["user_id"])
        self.assertEqual({row["domain"] for row in recent}, {"www.example.com", "video.example.net"})
        top = self.agent.visit_top(7, 20)
        self.assertEqual(sum(row["connections"] for row in top), 2)
        status = self.agent.visit_status()
        self.assertEqual(status["events"], 2)
        self.assertEqual(status["summaries"], 2)
        self.agent.clear_visit_history("CLEAR")
        self.assertEqual(self.agent.visit_status()["events"], 0)
        self.assertEqual(paths["xray"].stat().st_size, 0)

    def test_single_user_singbox_log_without_identity_is_attributed_locally(self):
        self.agent.config_path.unlink()
        self.agent.set_visit_monitor(True, 7, 30)
        path = self.agent.visit_log_paths()["singbox"]
        path.write_text(
            "INFO inbound/shadowsocks[ss-2022]: "
            "inbound connection to downloads.example.org:443\n",
            encoding="utf-8",
        )
        self.assertEqual(self.agent.collect_visit_logs(), 1)
        recent = self.agent.visit_recent(1, 10)
        self.assertEqual(recent[0]["user_name"], "本机用户")
        self.assertEqual(recent[0]["device_name"], "本机设备")

    def test_visit_retention_keeps_daily_summary_after_detail_expires(self):
        self.agent.set_visit_monitor(True, 7, 30)
        now = lun_agent.utc_now()
        device_id = self.agent.db.connection.execute(
            "SELECT id FROM devices WHERE legacy=1"
        ).fetchone()[0]
        old_event = now - 8 * 86400
        kept_day = (
            lun_agent.dt.datetime.fromtimestamp(old_event, lun_agent.dt.timezone.utc)
        ).strftime("%Y-%m-%d")
        expired_day = (
            lun_agent.dt.datetime.fromtimestamp(
                now - 31 * 86400, lun_agent.dt.timezone.utc
            )
        ).strftime("%Y-%m-%d")
        with self.agent.db.connection:
            self.agent.db.connection.execute(
                "INSERT INTO visit_events(occurred_at,device_id,core,network,inbound,domain,port) "
                "VALUES(?,?,?,?,?,?,?)",
                (old_event, device_id, "xray", "tcp", "test", "kept.example", 443),
            )
            for day, domain in (
                (kept_day, "kept.example"),
                (expired_day, "expired.example"),
            ):
                self.agent.db.connection.execute(
                    "INSERT INTO visit_daily(day,device_id,core,network,inbound,domain,port,"
                    "connections,first_seen,last_seen) VALUES(?,?,?,?,?,?,?,?,?,?)",
                    (day, device_id, "xray", "tcp", "test", domain, 443, 1, old_event, old_event),
                )
            self.agent._prune_visit_history(
                self.agent.visit_monitor_settings(), now
            )
        self.assertEqual(
            self.agent.db.connection.execute("SELECT COUNT(*) FROM visit_events").fetchone()[0],
            0,
        )
        domains = {
            row[0] for row in self.agent.db.connection.execute(
                "SELECT domain FROM visit_daily"
            )
        }
        self.assertEqual(domains, {"kept.example"})

    def test_visit_service_collects_once_before_waiting(self):
        self.agent.config_path.unlink()
        self.agent.set_visit_monitor(True, 7, 30)
        with mock.patch.object(self.agent, "collect_visit_logs") as collect, \
             mock.patch.object(lun_agent.threading.Event, "wait", return_value=True):
            lun_agent.serve_visits(self.agent)
        collect.assert_called_once_with()

    def test_subscription_port_can_be_updated_atomically(self):
        result = self.agent.set_subscription_port(32001, 52001)
        self.assertEqual(result, {"port": 32001, "public_port": 52001})
        config = self.agent.load_config()
        self.assertEqual(config["port"], 32001)
        self.assertEqual(config["public_port"], 52001)
        self.assertEqual((self.root / "subport.log").read_text(encoding="utf-8").strip(), "32001")

    def test_subscription_state_repairs_stale_legacy_files(self):
        device = self.agent.db.connection.execute(
            "SELECT * FROM devices WHERE legacy=1"
        ).fetchone()
        config = self.agent.load_config()
        config["legacy_token"] = "stale-config-token"
        self.agent.save_config(config)
        (self.root / "subtoken.log").write_text("stale-file-token\n", encoding="utf-8")
        (self.root / "subport.log").write_text("9999\n", encoding="utf-8")

        result = self.agent.sync_legacy_subscription_state()

        self.assertEqual(result["device_id"], device["id"])
        self.assertEqual(result["port"], 31000)
        self.assertEqual(result["public_port"], 31000)
        self.assertEqual(
            (self.root / "subtoken.log").read_text(encoding="utf-8").strip(),
            device["token"],
        )
        self.assertEqual((self.root / "subport.log").read_text(encoding="utf-8").strip(), "31000")
        self.assertEqual(self.agent.load_config()["legacy_token"], device["token"])
        if os.name != "nt":
            self.assertEqual((self.root / "subtoken.log").stat().st_mode & 0o777, 0o600)

    def test_local_subscription_output_uses_database_device_token(self):
        device = self.agent.local_subscription_device()
        (self.root / "subtoken.log").write_text("stale-file-token\n", encoding="utf-8")
        output = io.StringIO()
        with contextlib.redirect_stdout(output):
            lun_agent.print_subscription_links(device, self.agent.load_config())
        self.assertIn(f"/{device['token']}/jhsub.txt", output.getvalue())
        self.assertNotIn("stale-file-token", output.getvalue())

    def test_visit_collector_waits_for_a_complete_log_line(self):
        device = self.add_user()
        identity = f"lun:u:{device['user_id']}:d:{device['id']}"
        self.agent.set_visit_monitor(True, 7, 30)
        path = self.agent.visit_log_paths()["xray"]
        current = lun_agent.dt.datetime.now().astimezone().strftime("%Y/%m/%d %H:%M:%S")
        path.write_text(
            f"{current} accepted tcp:partial.example.com:443 "
            "[reality-vision -> direct]",
            encoding="utf-8",
        )
        self.assertEqual(self.agent.collect_visit_logs(), 0)
        with path.open("a", encoding="utf-8") as handle:
            handle.write(f" email: {identity}\n")
        self.assertEqual(self.agent.collect_visit_logs(), 1)
        self.assertEqual(self.agent.visit_recent(1, 10)[0]["domain"], "partial.example.com")

    def test_visit_retention_requires_summary_not_shorter_than_detail(self):
        with self.assertRaises(lun_agent.AgentError):
            self.agent.set_visit_monitor(True, 10, 7)

    def test_visit_smart_activity_merges_connections_and_hides_standard_noise(self):
        device = self.agent.db.connection.execute(
            "SELECT * FROM devices WHERE legacy=1"
        ).fetchone()
        now = lun_agent.utc_now()
        events = (
            (now - 1300, "tcp", "xhttp-h23", "www.semrush.com"),
            (now - 800, "udp", "reality-vision", "www.semrush.com"),
            (now - 100, "tcp", "xhttp-h23", "www.semrush.com"),
            (now - 90, "tcp", "xhttp-h23", "pagead2.googlesyndication.com"),
        )
        with self.agent.db.connection:
            self.agent.db.connection.executemany(
                "INSERT INTO visit_events(occurred_at,device_id,core,network,inbound,domain,port) "
                "VALUES(?,?,?,?,?,?,443)",
                [
                    (occurred_at, device["id"], "xray", network, inbound, domain)
                    for occurred_at, network, inbound, domain in events
                ],
            )
        smart = self.agent.visit_activity(1, 20)
        self.assertEqual(len(smart), 2)
        self.assertEqual({row["domain"] for row in smart}, {"www.semrush.com"})
        self.assertEqual(sorted(row["connections"] for row in smart), [1, 2])
        merged = next(row for row in smart if row["connections"] == 2)
        self.assertEqual((merged["has_tcp"], merged["has_udp"], merged["inbounds"]), (1, 1, 2))
        with_noise = self.agent.visit_activity(1, 20, include_noise=True)
        self.assertEqual(len(with_noise), 3)
        self.assertEqual(self.agent.visit_status()["events"], 4)

    def test_visit_filter_rules_use_allow_precedence_and_validate_domains(self):
        settings = self.agent.visit_monitor_settings()
        self.assertEqual(settings["filter_mode"], "standard")
        self.assertEqual(settings["merge_minutes"], 10)
        self.assertTrue(self.agent.visit_domain_is_noise("pagead2.googlesyndication.com"))
        self.assertFalse(self.agent.visit_domain_is_noise("mtalk.google.com"))
        self.assertFalse(self.agent.visit_domain_is_noise("client.crisp.chat"))
        self.assertFalse(self.agent.visit_domain_is_noise("www.semrush.com"))

        self.agent.update_visit_filter_rule("add-show", "googlesyndication.com")
        self.assertFalse(self.agent.visit_domain_is_noise("pagead2.googlesyndication.com"))
        self.agent.update_visit_filter_rule("add-hide", "semrush.com")
        self.assertTrue(self.agent.visit_domain_is_noise("www.semrush.com"))
        self.agent.update_visit_filter_rule("add-show", "www.semrush.com")
        self.assertFalse(self.agent.visit_domain_is_noise("www.semrush.com"))

        with self.assertRaises(lun_agent.AgentError):
            self.agent.update_visit_filter_rule("add-hide", "8.8.8.8")
        with self.assertRaises(lun_agent.AgentError):
            self.agent.update_visit_filter_rule("add-hide", "invalid")
        with self.assertRaises(lun_agent.AgentError):
            self.agent.set_visit_filter("standard", 0)

        reset = self.agent.reset_visit_filter_rules()
        self.assertEqual(reset["hidden_domains"], [])
        self.assertEqual(reset["allowed_domains"], [])

    def test_subscription_preserves_server_path_and_rewrites_identity(self):
        device = self.add_user()
        old = "11111111-1111-4111-8111-111111111111"
        name = "[德国-法兰克福]vless-xhttp-tls-tcp-01"
        source = f"vless://{old}@example.com:443?type=xhttp&path={old}-xc#{name}\n"
        rendered = self.agent.render_generic(source, device, self.agent.device_permissions(device["user_id"]), self.agent.load_config())
        self.assertIn(f"vless://{device['uuid']}@", rendered)
        self.assertIn(f"path={old}-xc", rendered)
        self.assertIn(name, rendered)

        singbox = {"outbounds": [{"type": "vless", "tag": name, "uuid": old}]}
        rendered_singbox = json.loads(self.agent.render_singbox(
            json.dumps(singbox, ensure_ascii=False), device,
            self.agent.device_permissions(device["user_id"]), self.agent.load_config(),
        ))
        self.assertEqual(rendered_singbox["outbounds"][0]["tag"], name)

        clash = f"""proxies:
- name: {name}
  type: vless
  server: example.com
  port: 443
  uuid: {old}
proxy-groups:
- name: AUTO
  type: select
  proxies:
    - {name}
rules:
  - MATCH,AUTO
"""
        rendered_clash = self.agent.render_clash(
            clash, device, self.agent.device_permissions(device["user_id"]), self.agent.load_config()
        )
        self.assertIn(f"- name: {name}", rendered_clash)

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

    def test_shadowsocks_is_omitted_when_nat_has_no_parallel_mapping(self):
        device = self.add_user()
        config = self.agent.load_config()
        config["ss_port"] = 0
        config["ss_public_port"] = 0
        permissions = self.agent.device_permissions(device["user_id"])
        payload = "2022-blake3-aes-128-gcm:legacy@example.com:20000"
        generic = "ss://" + base64.b64encode(payload.encode()).decode() + "#Shadowsocks-2022-test\n"
        self.assertEqual(self.agent.render_generic(generic, device, permissions, config), "")
        singbox = {
            "outbounds": [
                {"type": "shadowsocks", "tag": "Shadowsocks-2022-test", "server_port": 20000},
                {"type": "direct", "tag": "direct"},
            ]
        }
        rendered_singbox = json.loads(
            self.agent.render_singbox(json.dumps(singbox), device, permissions, config)
        )
        self.assertEqual([item["tag"] for item in rendered_singbox["outbounds"]], ["direct"])
        clash = """proxies:
- name: Shadowsocks-2022-test
  type: ss
  server: example.com
  port: 20000
  cipher: 2022-blake3-aes-128-gcm
  password: legacy
proxy-groups:
- name: AUTO
  type: select
  proxies:
  - Shadowsocks-2022-test
rules:
- MATCH,AUTO
"""
        rendered_clash = self.agent.render_clash(clash, device, permissions, config)
        self.assertNotIn("Shadowsocks-2022-test", rendered_clash)

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

    def test_cluster_subscription_returns_cache_before_async_refresh(self):
        token, filename, payload = self.add_cluster_subscription()
        observed = []
        with mock.patch.object(self.agent, "refresh_cluster_subscription_async") as refresh:
            refresh.side_effect = observed.append
            response = self.serve_subscription(token, filename)
        self.assertEqual(response.status, 200)
        self.assertEqual(response.wfile.getvalue(), payload)
        self.assertEqual(observed, [token])

    def test_cluster_refresh_uses_nonblocking_fixed_command_and_debounces(self):
        self.add_cluster_script()
        token = "cluster-token-123456"
        other = "cluster-token-654321"
        process = mock.Mock()
        with mock.patch.object(lun_agent.subprocess, "Popen", return_value=process) as popen, \
             mock.patch.object(lun_agent.threading, "Thread") as worker:
            self.agent.refresh_cluster_subscription_async(token)
            self.agent.refresh_cluster_subscription_async(token)
            self.agent.refresh_cluster_subscription_async(other)
        self.assertEqual(popen.call_count, 2)
        self.assertEqual(
            popen.call_args_list[0].args[0],
            [
                lun_agent.sys.executable,
                str(self.agent.root / "modules" / "cluster" / "lun_cluster.py"),
                "--root", str(self.agent.root), "subscription-access", "--token", token,
            ],
        )
        self.assertEqual(popen.call_args_list[0].kwargs["stdin"], subprocess.DEVNULL)
        self.assertEqual(popen.call_args_list[0].kwargs["stdout"], subprocess.DEVNULL)
        self.assertEqual(popen.call_args_list[0].kwargs["stderr"], subprocess.DEVNULL)
        self.assertTrue(popen.call_args_list[0].kwargs["start_new_session"])
        self.assertFalse(process.wait.called)
        self.assertEqual(worker.call_count, 2)
        self.assertNotIn(token, self.agent._cluster_refresh_started)
        self.assertIn(lun_agent.hashlib.sha256(token.encode()).hexdigest(), self.agent._cluster_refresh_started)

    def test_cluster_head_and_regular_device_do_not_trigger_refresh(self):
        token, filename, _ = self.add_cluster_subscription()
        with mock.patch.object(self.agent, "refresh_cluster_subscription_async") as refresh:
            response = self.serve_subscription(token, filename, send_body=False)
        self.assertEqual(response.status, 200)
        self.assertEqual(response.wfile.getvalue(), b"")
        refresh.assert_not_called()

        device = self.add_user()
        target = self.agent.generated / device["token"] / filename
        target.parent.mkdir(parents=True, exist_ok=True)
        target.write_bytes(b"regular-device")
        with mock.patch.object(self.agent, "refresh_cluster_subscription_async") as refresh:
            response = self.serve_subscription(device["token"], filename)
        self.assertEqual(response.status, 200)
        self.assertEqual(response.wfile.getvalue(), b"regular-device")
        refresh.assert_not_called()

    def test_cluster_refresh_errors_do_not_expose_token_or_break_cached_response(self):
        token, filename, payload = self.add_cluster_subscription()
        captured = io.StringIO()
        with contextlib.redirect_stderr(captured):
            response = self.serve_subscription(token, filename)
        self.assertEqual(response.status, 200)
        self.assertEqual(response.wfile.getvalue(), payload)
        self.assertNotIn(token, captured.getvalue())

        self.add_cluster_script()
        with contextlib.redirect_stderr(captured), \
             mock.patch.object(lun_agent.subprocess, "Popen", side_effect=OSError(token)):
            self.agent.refresh_cluster_subscription_async(token)
        self.assertNotIn(token, captured.getvalue())

    def test_subscription_only_initialization_preserves_cores_and_serves_static_and_cluster_files(self):
        core_xray = '{"inbounds":["unchanged"]}\n'
        core_singbox = '{"inbounds":["unchanged"]}\n'
        (self.root / "xr.json").write_text(core_xray, encoding="utf-8")
        (self.root / "sb.json").write_text(core_singbox, encoding="utf-8")
        (self.root / "jhsub.txt").write_text("vless://legacy\n", encoding="utf-8")
        args = argparse.Namespace(
            legacy_uuid=None, legacy_token=None, bind="127.0.0.1", port=31001,
            public_port=32001, legacy_http_port=0, legacy_http_public_port=0,
            scheme="http", public_host="example.com", certificate=None, private_key=None,
        )
        config = self.agent.initialize_subscription_only(args)
        legacy = self.agent.local_subscription_device()
        static = self.agent.generated / legacy["token"] / "jhsub.txt"
        self.assertFalse(config["enabled"])
        self.assertTrue(config["subscription_only"])
        self.assertEqual((self.root / "xr.json").read_text(encoding="utf-8"), core_xray)
        self.assertEqual((self.root / "sb.json").read_text(encoding="utf-8"), core_singbox)
        self.assertEqual(static.read_text(encoding="utf-8"), "vless://legacy\n")

        response = self.serve_subscription(legacy["token"], "jhsub.txt")
        self.assertEqual(response.status, 200)
        self.assertEqual(response.wfile.getvalue(), b"vless://legacy\n")
        token, filename, payload = self.add_cluster_subscription("cluster-token-789012")
        with mock.patch.object(self.agent, "refresh_cluster_subscription_async") as refresh:
            response = self.serve_subscription(token, filename)
        self.assertEqual(response.status, 200)
        self.assertEqual(response.wfile.getvalue(), payload)
        refresh.assert_called_once_with(token)

    def test_subscription_only_serve_skips_core_reconcile_and_maintenance(self):
        config = self.agent.load_config()
        config.update({"enabled": False, "subscription_only": True, "bind": "127.0.0.1", "port": 31002})
        self.agent.save_config(config)

        class Server:
            def __init__(self, *_args):
                self.socket = mock.Mock()

            def serve_forever(self, **_kwargs):
                pass

            def server_close(self):
                pass

        with mock.patch.object(lun_agent.http.server, "ThreadingHTTPServer", Server), \
             mock.patch.object(self.agent, "reconcile") as reconcile, \
             mock.patch.object(self.agent, "maintenance_once") as maintenance, \
             mock.patch.object(lun_agent.threading, "Thread") as worker:
            lun_agent.serve(self.agent)
        reconcile.assert_not_called()
        maintenance.assert_not_called()
        worker.assert_not_called()

    def test_regular_initialization_clears_subscription_only_without_rotating_legacy_identity(self):
        previous = self.agent.local_subscription_device()
        self.agent.initialize_subscription_only(argparse.Namespace(
            legacy_uuid=None, legacy_token=None, bind="127.0.0.1", port=31001,
            public_port=31001, legacy_http_port=0, legacy_http_public_port=0,
            scheme="http", public_host="example.com", certificate=None, private_key=None,
        ))
        self.agent.initialize(argparse.Namespace(
            legacy_uuid=None, legacy_token=None, bind="127.0.0.1", port=31000,
            public_port=31000, legacy_http_port=0, legacy_http_public_port=0,
            scheme="http", public_host="example.com", certificate=None, private_key=None,
            xray_api="127.0.0.1:10085", singbox_api="127.0.0.1:10086", poll_interval=30,
            ss_port=32000, ss_public_port=32000, ss_server_password="AAAAAAAAAAAAAAAAAAAAAA==",
        ))
        current = self.agent.local_subscription_device()
        self.assertTrue(self.agent.load_config()["enabled"])
        self.assertFalse(self.agent.load_config()["subscription_only"])
        self.assertEqual(current["id"], previous["id"])
        self.assertEqual(current["token"], previous["token"])

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
