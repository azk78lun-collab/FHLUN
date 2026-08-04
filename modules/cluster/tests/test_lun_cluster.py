from __future__ import annotations

import base64
import contextlib
import importlib.util
import io
import json
import shutil
import socket
import ssl
import tempfile
import threading
import time
import unittest
from pathlib import Path


MODULE_PATH = Path(__file__).resolve().parents[1] / "lun_cluster.py"
SPEC = importlib.util.spec_from_file_location("lun_cluster", MODULE_PATH)
lun_cluster = importlib.util.module_from_spec(SPEC)
assert SPEC.loader
SPEC.loader.exec_module(lun_cluster)


def free_port() -> int:
    with socket.socket() as listener:
        listener.bind(("127.0.0.1", 0))
        return listener.getsockname()[1]


class ClusterTestCase(unittest.TestCase):
    def setUp(self) -> None:
        self.temporary = tempfile.TemporaryDirectory()
        self.root = Path(self.temporary.name) / "lun"
        self.root.mkdir()
        (self.root / "uuid").write_text("11111111-1111-4111-8111-111111111111\n", encoding="utf-8")
        self.cluster = lun_cluster.Cluster(self.root)

    def tearDown(self) -> None:
        self.cluster.close()
        self.temporary.cleanup()

    def test_join_uri_round_trip_and_expiry(self) -> None:
        value = lun_cluster.make_join_uri(
            "2001:db8::1", 34567, "a" * 32, "x" * 43, "b" * 64, lun_cluster.utc_now() + 60
        )
        parsed = lun_cluster.parse_join_uri(value)
        self.assertEqual(parsed["host"], "2001:db8::1")
        self.assertEqual(parsed["port"], 34567)
        expired = value.rsplit("=", 1)[0] + "=1"
        with self.assertRaisesRegex(lun_cluster.ClusterError, "过期"):
            lun_cluster.parse_join_uri(expired)

    def test_join_token_is_one_time(self) -> None:
        digest = lun_cluster.hashlib.sha256(b"secret-token-value-that-is-long-enough").hexdigest()
        with self.cluster.db.connection:
            self.cluster.db.connection.execute(
                "INSERT INTO join_tokens(token_hash,expires_at,created_at) VALUES(?,?,?)",
                (digest, lun_cluster.utc_now() + 60, lun_cluster.utc_now()),
            )
        self.cluster.consume_join_token("secret-token-value-that-is-long-enough")
        with self.assertRaisesRegex(lun_cluster.ClusterError, "已使用"):
            self.cluster.consume_join_token("secret-token-value-that-is-long-enough")

    def test_environment_allowlist_and_ports(self) -> None:
        result = lun_cluster.validate_lun_environment({"vlpt": 12345, "vpsmode": "normal"})
        self.assertEqual(result["vlpt"], "12345")
        with self.assertRaisesRegex(lun_cluster.ClusterError, "不支持"):
            lun_cluster.validate_lun_environment({"command": "rm -rf /"})
        with self.assertRaisesRegex(lun_cluster.ClusterError, "有效端口"):
            lun_cluster.validate_lun_environment({"vlpt": 70000})
        with self.assertRaisesRegex(lun_cluster.ClusterError, "ptmap"):
            lun_cluster.validate_lun_environment({"ptmap": "1234;evil"})

    def test_usage_reports_are_absolute_and_idempotent(self) -> None:
        node_id = "a" * 32
        self._add_node(node_id, "DE")
        self.assertTrue(self.cluster.record_usage(node_id, "device", "2026-08", 10, 20, 5, 6, 2))
        self.assertFalse(self.cluster.record_usage(node_id, "device", "2026-08", 999, 999, 999, 999, 1))
        totals = self.cluster.global_usage("device", "2026-08")
        self.assertEqual(totals["uplink"], 10)
        self.assertEqual(totals["month_downlink"], 6)
        gib = 1024 ** 3
        self.assertEqual(self.cluster.usage_threshold(100 * gib, 50 * gib), 10 * gib)
        self.assertEqual(self.cluster.usage_threshold(100 * gib, 80 * gib), 5 * gib)
        self.assertEqual(self.cluster.usage_threshold(100 * gib, 95 * gib), gib)

    def test_user_node_assignment_replaces_previous_selection(self) -> None:
        first, second = "a" * 32, "b" * 32
        self._add_node(first, "DE")
        self._add_node(second, "HK")
        self.cluster.assign_user_nodes(7, ["1", "2"])
        self.cluster.assign_user_nodes(7, ["2"])
        rows = self.cluster.db.connection.execute(
            "SELECT node_id FROM user_nodes WHERE user_id=7"
        ).fetchall()
        self.assertEqual([row[0] for row in rows], [second])

    def test_node_numbers_and_status_location_are_chinese(self) -> None:
        first, second = "a" * 32, "b" * 32
        self._add_node(first, "JP")
        self._add_node(second, "US")
        self.cluster.set_location(first, "JP", "Japan", "Osaka", "Minoh")
        self.cluster.set_location(second, "US", "United States", "California", "Los Angeles")
        with self.cluster.db.connection:
            self.cluster.db.connection.execute("UPDATE nodes SET state='unreachable' WHERE id=?", (second,))
        rows = self.cluster.nodes()
        self.assertEqual([row["number"] for row in rows], [1, 2])
        self.assertEqual(self.cluster.node("1")["id"], first)
        self.assertEqual(self.cluster.node("2")["id"], second)
        output = io.StringIO()
        with contextlib.redirect_stdout(output):
            lun_cluster.print_nodes(rows)
        text = output.getvalue()
        self.assertIn("编号", text)
        self.assertIn("在线", text)
        self.assertIn("离线", text)
        self.assertIn("日本-箕面", text)
        self.assertIn("美国-洛杉矶", text)
        self.assertNotIn(first[:8], text)
        self.assertEqual(lun_cluster.infer_country_code("美国-洛杉矶"), "US")
        self.assertEqual(
            lun_cluster.chinese_place({"country_code": "DE", "region": "德国-法兰克福"}),
            "德国-法兰克福",
        )

    def test_subscription_aggregation_prefixes_and_groups_regions(self) -> None:
        de, hk = "a" * 32, "b" * 32
        self._record_sample(de, "DE", "Frankfurt", "德国")
        self._record_sample(hk, "HK", "Hong Kong", "香港")
        generated = self.cluster.aggregate("all")
        self.assertIn("%5BDE-Frankfurt%5D%5B%E5%BE%B7%E5%9B%BD%5D", generated["jhsub.txt"])
        self.assertIn("[HK-Hong Kong][香港]", generated["clmi.yaml"])
        self.assertIn("Lun DE", generated["clmi.yaml"])
        singbox = json.loads(generated["sbox.json"])
        tags = [item["tag"] for item in singbox["outbounds"]]
        self.assertIn("Lun HK", tags)
        region = self.cluster.aggregate("region:DE")
        self.assertIn("DE-Frankfurt", region["clmi.yaml"])
        self.assertNotIn("Hong Kong", region["clmi.yaml"])

    @unittest.skipUnless(shutil.which("openssl"), "OpenSSL is required")
    def test_encrypted_backup_detects_wrong_password_and_restores(self) -> None:
        port = free_port()
        self.cluster.init_master("127.0.0.1", port, port, "master")
        backup = Path(self.temporary.name) / "cluster.backup"
        self.cluster.export_backup(backup, "correct-password")
        self.cluster.db.set_setting("changed", "yes")
        with self.assertRaisesRegex(lun_cluster.ClusterError, "口令错误"):
            self.cluster.restore_backup(backup, "wrong-password")
        result = self.cluster.restore_backup(backup, "correct-password")
        self.assertEqual(result["manifest"]["cluster_id"], self.cluster.load_config()["cluster_id"])
        self.assertEqual(self.cluster.db.setting("changed"), "")

    @unittest.skipUnless(shutil.which("openssl"), "OpenSSL is required")
    def test_bootstrap_pairing_pins_certificate_and_rejects_replay(self) -> None:
        master_root = Path(self.temporary.name) / "master"
        child_root = Path(self.temporary.name) / "child"
        master_root.mkdir()
        child_root.mkdir()
        (master_root / "uuid").write_text("22222222-2222-4222-8222-222222222222", encoding="utf-8")
        (child_root / "uuid").write_text("33333333-3333-4333-8333-333333333333", encoding="utf-8")
        master = lun_cluster.Cluster(master_root)
        child = lun_cluster.Cluster(child_root)
        port = free_port()
        master.init_master("127.0.0.1", free_port(), free_port(), "master")
        child_result = child.init_child("127.0.0.1", port, port, "child")
        server = lun_cluster.ThreadingClusterServer(("127.0.0.1", port), lun_cluster.ClusterHandler)
        server.cluster = child
        server.restart_requested = False
        server.socket = lun_cluster.server_context(child).wrap_socket(server.socket, server_side=True)
        thread = threading.Thread(target=server.serve_forever, daemon=True)
        thread.start()
        try:
            row = lun_cluster.add_node(master, child_result["join_uri"], "child")
            self.assertEqual(row["id"], child.load_config()["node_id"])
            self.assertTrue(child.load_config()["paired"])
            with self.assertRaises(lun_cluster.ClusterError):
                lun_cluster.add_node(master, child_result["join_uri"], "child")
            server.shutdown()
            server.server_close()
            thread.join(timeout=5)
            server = lun_cluster.ThreadingClusterServer(("127.0.0.1", port), lun_cluster.ClusterHandler)
            server.cluster = child
            server.restart_requested = False
            server.socket = lun_cluster.server_context(child).wrap_socket(server.socket, server_side=True)
            thread = threading.Thread(target=server.serve_forever, daemon=True)
            thread.start()
            status = lun_cluster.mutual_request(master, "127.0.0.1", port, "GET", "/v1/status")
            self.assertEqual(status["status"]["node_id"], child.load_config()["node_id"])
        finally:
            server.shutdown()
            server.server_close()
            thread.join(timeout=5)
            master.close()
            child.close()

    def test_action_is_idempotent_and_unknown_action_is_rejected(self) -> None:
        config = {
            "enabled": True, "role": "child", "node_id": "a" * 32, "public_host": "127.0.0.1",
            "public_port": 30000, "internal_port": 30000,
        }
        self.cluster.save_config(config)
        request = {"request_id": "1" * 32, "action": "status.refresh", "payload": {}}
        first = lun_cluster.execute_action(self.cluster, request)
        second = lun_cluster.execute_action(self.cluster, request)
        self.assertEqual(first["status"], "success")
        self.assertTrue(second["replayed"])
        with self.assertRaisesRegex(lun_cluster.ClusterError, "允许列表"):
            lun_cluster.execute_action(
                self.cluster, {"request_id": "2" * 32, "action": "shell.run", "payload": {}}
            )

    def test_snapshot_restore_replaces_protocol_state(self) -> None:
        (self.root / "xr.json").write_text('{"old":true}\n', encoding="utf-8")
        (self.root / "port_vl_re").write_text("12345\n", encoding="utf-8")
        snapshot = self.cluster.create_snapshot("test")
        (self.root / "xr.json").write_text('{"old":false}\n', encoding="utf-8")
        (self.root / "port_vl_re").unlink()
        (self.root / "port_xh").write_text("23456\n", encoding="utf-8")
        result = self.cluster.restore_snapshot(snapshot)
        self.assertIn("rollback", result)
        self.assertEqual((self.root / "xr.json").read_text(encoding="utf-8"), '{"old":true}\n')
        self.assertEqual((self.root / "port_vl_re").read_text(encoding="utf-8"), "12345\n")
        self.assertFalse((self.root / "port_xh").exists())

    def _add_node(self, node_id: str, country: str) -> None:
        self.cluster.upsert_node({
            "node_id": node_id, "public_host": "127.0.0.1", "public_port": 20000,
            "internal_port": 20000, "api_version": 1,
            "location": {"country_code": country},
        })

    def _record_sample(self, node_id: str, country: str, city: str, remark: str) -> None:
        status = {
            "node_id": node_id, "public_host": "127.0.0.1", "public_port": 20000,
            "internal_port": 20000, "api_version": 1, "remark": remark,
            "location": {"country_code": country, "city": city},
        }
        generic = "vless://11111111-1111-4111-8111-111111111111@127.0.0.1:443#VLESS\n"
        clash = """proxies:
- name: VLESS
  type: vless
  server: 127.0.0.1
  port: 443
  uuid: 11111111-1111-4111-8111-111111111111
proxy-groups:
- name: select
  type: select
  proxies:
    - VLESS
rules:
  - MATCH,select
"""
        singbox = json.dumps({
            "inbounds": [], "outbounds": [{"type": "vless", "tag": "VLESS", "server": "127.0.0.1",
                                               "server_port": 443, "uuid": "11111111-1111-4111-8111-111111111111"}],
            "route": {"rules": []},
        })
        self.cluster.record_snapshot({
            "status": status, "profile_key": "legacy", "files": {
                "jhsub.txt": base64.b64encode(generic.encode()).decode(),
                "clmi.yaml": base64.b64encode(clash.encode()).decode(),
                "sbox.json": base64.b64encode(singbox.encode()).decode(),
            },
        })


if __name__ == "__main__":
    unittest.main()
