from __future__ import annotations

import base64
import contextlib
import importlib.util
import io
import json
import shutil
import socket
import sqlite3
import ssl
import tarfile
import tempfile
import threading
import time
import unittest
from pathlib import Path
from unittest import mock


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
        self.assertEqual(self.cluster.node("01")["id"], first)
        self.assertEqual(self.cluster.node("2")["id"], second)
        output = io.StringIO()
        with contextlib.redirect_stdout(output):
            lun_cluster.print_nodes(rows)
        text = output.getvalue()
        self.assertIn("编号", text)
        self.assertIn("在线", text)
        self.assertIn("离线", text)
        self.assertIn("日本-大阪", text)
        self.assertNotIn("日本-箕面", text)
        self.assertIn("美国-洛杉矶", text)
        self.assertNotIn(first[:8], text)
        self.assertEqual(lun_cluster.infer_country_code("美国-洛杉矶"), "US")
        self.assertEqual(
            lun_cluster.chinese_place({"country_code": "DE", "region": "德国-法兰克福"}),
            "德国-法兰克福",
        )

    def test_master_nodes_view_refreshes_its_own_runtime_version(self) -> None:
        node_id = "a" * 32
        self.cluster.save_config({
            "enabled": True, "role": "master", "node_id": node_id, "cluster_id": "b" * 32,
            "public_host": "127.0.0.1", "public_port": 20000, "internal_port": 20000,
            "paired": True, "location": {"country_code": "JP"},
        })
        status = self.cluster.local_status()
        status["lun_version"] = "Vold"
        self.cluster.upsert_node(status, role="master")
        with mock.patch.object(self.cluster, "_lun_version", return_value="Vnew"):
            rows = self.cluster.nodes()
        self.assertEqual(rows[0]["lun_version"], "Vnew")

    def test_subscription_aggregation_keeps_canonical_names_and_groups_regions(self) -> None:
        de, hk = "a" * 32, "b" * 32
        self._record_sample(de, "DE", "Frankfurt", "德国")
        self._record_sample(hk, "HK", "Hong Kong", "香港")
        generated = self.cluster.aggregate("all")
        self.assertIn("[德国-法兰克福]vless-xhttp-tls-tcp-01", generated["jhsub.txt"])
        self.assertIn("[中国香港-香港]vless-xhttp-tls-tcp-02", generated["clmi.yaml"])
        self.assertNotIn("[DE-Frankfurt]", generated["jhsub.txt"])
        self.assertNotIn("[德国]", generated["jhsub.txt"])
        self.assertIn("Lun DE", generated["clmi.yaml"])
        singbox = json.loads(generated["sbox.json"])
        tags = [item["tag"] for item in singbox["outbounds"]]
        self.assertIn("Lun HK", tags)
        region = self.cluster.aggregate("region:DE")
        self.assertIn("德国-法兰克福", region["clmi.yaml"])
        self.assertNotIn("Hong Kong", region["clmi.yaml"])

    def test_child_snapshot_event_refreshes_public_aggregate(self) -> None:
        master_id, child_id = "a" * 32, "b" * 32
        self.cluster.save_config({
            "enabled": True, "role": "master", "node_id": master_id,
            "public_host": "127.0.0.1", "public_port": 20000, "internal_port": 20000,
        })
        self.cluster.upsert_node({
            "node_id": master_id, "public_host": "127.0.0.1", "public_port": 20000,
            "internal_port": 20000, "api_version": 1,
            "location": {"country_code": "JP", "city": "Osaka"},
        }, role="master")
        self.cluster.upsert_node({
            "node_id": child_id, "public_host": "198.51.100.2", "public_port": 21000,
            "internal_port": 21000, "api_version": 1,
            "location": {"country_code": "DE", "city": "Frankfurt"},
        }, role="child")
        node_name = "[德国-法兰克福]vless-xhttp-tls-tcp-02"
        snapshot = {
            "status": {
                "node_id": child_id, "public_host": "198.51.100.2", "public_port": 21000,
                "internal_port": 21000, "api_version": 1,
                "location": {"country_code": "DE", "city": "Frankfurt"},
            },
            "profile_key": "legacy",
            "files": {
                "jhsub.txt": base64.b64encode(
                    f"vless://11111111-1111-4111-8111-111111111111@198.51.100.2:443#{node_name}\n".encode()
                ).decode(),
                "clmi.yaml": base64.b64encode(b"proxies: []\nproxy-groups: []\nrules: []\n").decode(),
                "sbox.json": base64.b64encode(b'{"inbounds":[],"outbounds":[],"route":{"rules":[]}}').decode(),
            },
        }
        handler = object.__new__(lun_cluster.ClusterHandler)
        handler.server = type("Server", (), {"cluster": self.cluster})()
        handler.path = "/v1/events/snapshot"
        handler._body = mock.Mock(return_value={"snapshot": snapshot})
        handler._require_peer = mock.Mock(return_value=child_id)
        handler._reply = mock.Mock()

        with mock.patch.object(
            lun_cluster, "push_node_identity", side_effect=AssertionError("unexpected identity sync")
        ):
            handler.do_POST()

        handler._reply.assert_called_once_with(200, {"ok": True})
        generated = list((self.root / "modules" / "cluster" / "generated").glob("*/jhsub.txt"))
        self.assertTrue(generated)
        self.assertTrue(any(node_name in path.read_text(encoding="utf-8") for path in generated))
        self.cluster = lun_cluster.Cluster(self.root)

    def test_minoh_names_are_canonicalized_to_osaka_in_all_subscriptions(self) -> None:
        node_id = "c" * 32
        server_number = self.cluster.allocate_server_number(node_id)
        old_name = f"[日本-箕面]naive-h3-{server_number:02d}"
        status = {
            "node_id": node_id, "public_host": "127.0.0.1", "public_port": 20000,
            "internal_port": 20000, "api_version": 1,
            "location": {"country_code": "JP", "region": "Osaka", "city": "Minoh"},
        }
        generic = f"naive+quic://uuid:uuid@127.0.0.1:443#{old_name}\n"
        clash = f"proxies:\n- name: {old_name}\n  type: vless\nproxy-groups:\n"
        singbox = json.dumps({
            "inbounds": [], "outbounds": [{"type": "naive", "tag": old_name}],
            "route": {"rules": []},
        })
        self.cluster.record_snapshot({
            "status": status, "profile_key": "legacy", "files": {
                "jhsub.txt": base64.b64encode(generic.encode()).decode(),
                "clmi.yaml": base64.b64encode(clash.encode()).decode(),
                "sbox.json": base64.b64encode(singbox.encode()).decode(),
            },
        })
        generated = self.cluster.aggregate("all")
        for content in generated.values():
            self.assertNotIn("日本-箕面", content)
        self.assertIn("[日本-大阪]naive-h3", generated["jhsub.txt"])
        self.assertIn("[日本-大阪]naive-h3", generated["clmi.yaml"])
        self.assertIn("[日本-大阪]naive-h3", generated["sbox.json"])

    def test_duplicate_places_are_numbered_in_all_subscription_formats(self) -> None:
        first, second = "d" * 32, "e" * 32
        self._record_sample(first, "JP", "Osaka", "Osaka-A")
        self._record_sample(second, "JP", "Minoh", "Osaka-B")
        labels = self.cluster.place_labels()
        self.assertEqual(labels[first], "日本-大阪1")
        self.assertEqual(labels[second], "日本-大阪2")
        generated = self.cluster.aggregate("all")
        for content in generated.values():
            self.assertIn("[日本-大阪1]vless-xhttp-tls-tcp-01", content)
            self.assertIn("[日本-大阪2]vless-xhttp-tls-tcp-02", content)
            self.assertNotIn("[日本-大阪]vless-xhttp", content)

    def test_duplicate_place_changes_identity_signature_and_node_view(self) -> None:
        first, second = "d" * 32, "e" * 32
        self._add_node(first, "JP")
        self.cluster.set_location(first, "JP", "日本", "Osaka", "Minoh")
        self.cluster.mark_identity_synced(self.cluster.node(first))
        self._add_node(second, "JP")
        self.cluster.set_location(second, "JP", "日本", "Osaka", "Osaka")
        self.assertTrue(self.cluster.identity_sync_pending(self.cluster.node(first)))
        output = io.StringIO()
        with contextlib.redirect_stdout(output):
            lun_cluster.print_nodes(self.cluster.nodes())
        self.assertIn("日本-大阪1", output.getvalue())
        self.assertIn("日本-大阪2", output.getvalue())

    def test_server_numbers_are_stable_and_never_reused(self) -> None:
        first, second, third = "a" * 32, "b" * 32, "c" * 32
        self._add_node(first, "DE")
        self._add_node(second, "JP")
        self.cluster.save_config({
            "enabled": True, "role": "master", "node_id": first, "public_host": "127.0.0.1",
            "public_port": 20000, "internal_port": 20000,
        })
        self.cluster.remove_node(second)
        self._add_node(third, "US")
        self.assertEqual(self.cluster.node(first)["server_number"], 1)
        self.assertEqual(self.cluster.node(third)["server_number"], 3)
        self.assertEqual(
            self.cluster.db.connection.execute(
                "SELECT server_number FROM node_number_history WHERE node_id=?", (second,)
            ).fetchone()[0],
            2,
        )

    def test_local_identity_files_use_chinese_place_and_padded_number(self) -> None:
        self.cluster.save_config({
            "enabled": True, "role": "child", "node_id": "a" * 32,
            "public_host": "127.0.0.1", "public_port": 20000, "internal_port": 20000,
        })
        identity = self.cluster.apply_local_identity(7, {
            "country_code": "DE", "country": "Germany", "region": "Hesse", "city": "Frankfurt",
        })
        self.assertEqual(identity["place"], "德国-法兰克福")
        self.assertEqual((self.root / "server_number").read_text(encoding="utf-8"), "07\n")
        self.assertEqual((self.root / "server_place").read_text(encoding="utf-8"), "德国-法兰克福\n")

    def test_local_identity_accepts_cluster_duplicate_place_label(self) -> None:
        self.cluster.save_config({
            "enabled": True, "role": "child", "node_id": "a" * 32,
            "public_host": "127.0.0.1", "public_port": 20000, "internal_port": 20000,
        })
        identity = self.cluster.apply_local_identity(
            2, {"country_code": "JP", "region": "Osaka", "city": "Minoh"}, "日本-大阪2"
        )
        self.assertEqual(identity["place"], "日本-大阪2")
        self.assertEqual((self.root / "server_place").read_text(encoding="utf-8"), "日本-大阪2\n")
        self.assertEqual(self.cluster.load_config()["place"], "日本-大阪2")

    def test_identity_sync_marker_changes_only_with_number_or_location(self) -> None:
        node_id = "a" * 32
        self._add_node(node_id, "DE")
        row = self.cluster.node(node_id)
        self.assertTrue(self.cluster.identity_sync_pending(row))
        self.cluster.mark_identity_synced(row)
        self.assertFalse(self.cluster.identity_sync_pending(self.cluster.node(node_id)))
        self.cluster.set_location(node_id, "DE", "德国", "德国-柏林")
        self.assertTrue(self.cluster.identity_sync_pending(self.cluster.node(node_id)))

    @unittest.skipUnless(shutil.which("openssl"), "OpenSSL is required")
    def test_role_transfer_promotes_child_without_renumbering_and_can_rollback(self) -> None:
        master_root = Path(self.temporary.name) / "role-master"
        child_root = Path(self.temporary.name) / "role-child"
        master_root.mkdir()
        child_root.mkdir()
        (master_root / "uuid").write_text("22222222-2222-4222-8222-222222222222", encoding="utf-8")
        (child_root / "uuid").write_text("33333333-3333-4333-8333-333333333333", encoding="utf-8")
        master = lun_cluster.Cluster(master_root)
        child = lun_cluster.Cluster(child_root)
        try:
            master_config = master.init_master("127.0.0.1", free_port(), free_port(), "master")
            child_config = child.init_child("127.0.0.1", free_port(), free_port(), "oracle")
            certificate = master._sign_csr(
                (child.pki / "node.csr").read_text(encoding="utf-8"), child_config["node_id"],
                master.pki / f"issued-{child_config['node_id']}.crt",
            )
            (child.pki / "cluster-ca.crt").write_bytes((master.pki / "cluster-ca.crt").read_bytes())
            (child.pki / "node.crt").write_text(certificate, encoding="utf-8")
            child_config.update({
                "cluster_id": master_config["cluster_id"], "controller_id": master_config["node_id"],
                "controller_host": master_config["public_host"],
                "controller_port": master_config["public_port"], "paired": True,
            })
            child.save_config(child_config)
            master.upsert_node(child.local_status(), remark="oracle")
            target = master.node(child_config["node_id"])
            self.assertEqual(target["server_number"], 2)
            data = master.build_role_transfer(str(target["id"]))
            transfer_id = "f" * 32
            digest = lun_cluster.hashlib.sha256(data).hexdigest()
            total = (len(data) + lun_cluster.ROLE_TRANSFER_CHUNK - 1) // lun_cluster.ROLE_TRANSFER_CHUNK
            for index in range(total):
                chunk = data[index * lun_cluster.ROLE_TRANSFER_CHUNK:(index + 1) * lun_cluster.ROLE_TRANSFER_CHUNK]
                child.stage_role_transfer({
                    "transfer_id": transfer_id, "sha256": digest,
                    "source_id": master_config["node_id"], "target_id": child_config["node_id"],
                    "index": index, "total": total, "size": len(data),
                    "data": base64.b64encode(chunk).decode(),
                }, master_config["node_id"])
            promoted = child.promote_from_role_transfer(transfer_id, master_config["node_id"])
            self.assertEqual(promoted["role"], "master")
            self.assertEqual(child.load_config()["role"], "master")
            self.assertEqual(child.node(child_config["node_id"])["server_number"], 2)
            self.assertEqual(child.node(master_config["node_id"])["role"], "child")
            self.assertTrue((child.pki / "cluster-ca.key").is_file())
            self.assertFalse((child.role_transfer_dir / transfer_id).exists())
            child.rollback_role_promotion(master_config["node_id"])
            self.assertEqual(child.load_config()["role"], "child")
            self.assertEqual(child.load_config()["controller_id"], master_config["node_id"])
            self.assertFalse((child.pki / "cluster-ca.key").exists())
        finally:
            master.close()
            child.close()

    def test_controller_transition_requires_current_then_pending_controller(self) -> None:
        old_id, new_id = "a" * 32, "b" * 32
        self.cluster.save_config({
            "enabled": True, "role": "child", "node_id": "c" * 32,
            "cluster_id": "d" * 32, "controller_id": old_id,
            "controller_host": "192.0.2.1", "controller_port": 20000,
            "public_host": "127.0.0.1", "public_port": 21000, "internal_port": 21000,
            "paired": True,
        })
        prepared = lun_cluster.execute_action(self.cluster, {
            "request_id": "1" * 32, "action": "controller.prepare",
            "payload": {"controller": {"id": new_id, "host": "198.51.100.2", "port": 22000}},
        }, old_id)
        self.assertEqual(prepared["status"], "success")
        with self.assertRaisesRegex(lun_cluster.ClusterError, "临时授权"):
            lun_cluster.execute_action(self.cluster, {
                "request_id": "2" * 32, "action": "controller.commit", "payload": {},
            }, "e" * 32)
        lun_cluster.execute_action(self.cluster, {
            "request_id": "3" * 32, "action": "controller.commit", "payload": {},
        }, new_id)
        config = self.cluster.load_config()
        self.assertEqual(config["controller_id"], new_id)
        self.assertEqual(config["controller_host"], "198.51.100.2")
        self.assertNotIn("pending_controller", config)

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
        old_script = lun_cluster.os.environ.get("LUN_SCRIPT")
        lun_cluster.os.environ["LUN_SCRIPT"] = str(Path(self.temporary.name) / "no-real-lun-script")
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
            replacement_uri = child.create_join_code()
            replacement = lun_cluster.add_node(master, replacement_uri)
            self.assertEqual(replacement["id"], child.load_config()["node_id"])
            with self.assertRaises(lun_cluster.ClusterError):
                lun_cluster.add_node(master, replacement_uri)
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
            if old_script is None:
                lun_cluster.os.environ.pop("LUN_SCRIPT", None)
            else:
                lun_cluster.os.environ["LUN_SCRIPT"] = old_script

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

    def test_service_control_is_fixed_and_cluster_cannot_be_stopped(self) -> None:
        script = Path(self.temporary.name) / "bin-lun"
        script.write_text("#!/bin/sh\nexit 0\n", encoding="utf-8")
        old_script = lun_cluster.os.environ.get("LUN_SCRIPT")
        lun_cluster.os.environ["LUN_SCRIPT"] = str(script)
        try:
            completed = lun_cluster.subprocess.CompletedProcess([], 0, "Xray：运行中\n", "")
            with mock.patch.object(self.cluster, "_run", return_value=completed) as run:
                result = lun_cluster.execute_action(self.cluster, {
                    "request_id": "3" * 32, "action": "service.control",
                    "payload": {"component": "xray", "operation": "restart"},
                })
            self.assertEqual(result["status"], "success")
            self.assertEqual(
                run.call_args.args[0],
                ["bash", str(script), "cluster-service-control", "xray", "restart"],
            )
            with self.assertRaisesRegex(lun_cluster.ClusterError, "仅允许"):
                lun_cluster.execute_action(self.cluster, {
                    "request_id": "4" * 32, "action": "service.control",
                    "payload": {"component": "cluster", "operation": "stop"},
                })
            with self.assertRaisesRegex(lun_cluster.ClusterError, "参数无效"):
                lun_cluster.execute_action(self.cluster, {
                    "request_id": "5" * 32, "action": "service.control",
                    "payload": {"component": "shell", "operation": "restart"},
                })
        finally:
            if old_script is None:
                lun_cluster.os.environ.pop("LUN_SCRIPT", None)
            else:
                lun_cluster.os.environ["LUN_SCRIPT"] = old_script

    def test_cluster_update_distribution_skips_source_and_excluded_nodes(self) -> None:
        master_id, source_id, target_id, excluded_id = "a" * 32, "b" * 32, "c" * 32, "d" * 32
        self.cluster.save_config({
            "enabled": True, "role": "master", "node_id": master_id,
            "public_host": "127.0.0.1", "public_port": 20000, "internal_port": 20000,
        })
        self.cluster.upsert_node({
            "node_id": master_id, "public_host": "127.0.0.1", "public_port": 20000,
            "internal_port": 20000, "api_version": 1, "location": {"country_code": "JP"},
        }, role="master")
        for node_id, port in ((source_id, 21000), (target_id, 22000), (excluded_id, 23000)):
            self.cluster.upsert_node({
                "node_id": node_id, "public_host": "127.0.0.1", "public_port": port,
                "internal_port": port, "api_version": 1, "location": {"country_code": "DE"},
            }, role="child")
        script_payload, agent_payload = self._update_payloads()
        calls: list[tuple[str, str]] = []

        def fake_send(_cluster, node_id, action, payload, timeout=900):
            calls.append((node_id, action))
            if action == "status.refresh":
                return {"result": {
                    "node_id": node_id, "public_host": "127.0.0.1", "public_port": 22000,
                    "internal_port": 22000, "api_version": 1, "location": {"country_code": "DE"},
                }}
            return {"result": {"sha256": payload["sha256"]}}

        with mock.patch.object(lun_cluster, "send_action", side_effect=fake_send):
            result = lun_cluster.distribute_cluster_update(
                self.cluster,
                {"script": script_payload, "agent": agent_payload, "exclude": "4"},
                source_peer=source_id,
            )
        self.assertEqual(calls, [
            (target_id, "status.refresh"),
            (target_id, "script.install"),
            (target_id, "agent.install"),
        ])
        self.assertTrue(result["complete"])
        self.assertEqual(result["version"], "V26.8.8.3")
        self.assertEqual(result["nodes"]["2"]["status"], "source-current")
        self.assertEqual(result["nodes"]["3"]["script_sha256"], script_payload["sha256"])
        self.assertEqual(result["nodes"]["4"]["status"], "excluded")

    def test_cluster_update_child_requests_master(self) -> None:
        self.cluster.save_config({
            "enabled": True, "role": "child", "node_id": "b" * 32,
            "cluster_id": "e" * 32, "controller_id": "a" * 32,
            "controller_host": "192.0.2.10", "controller_port": 20000,
            "public_host": "127.0.0.1", "public_port": 21000,
            "internal_port": 21000, "paired": True,
        })
        payload = {"script": {}, "agent": {}, "exclude": "4"}
        response = {
            "result": {"status": "success", "result": {"complete": True, "version": "V26.8.8.3"}}
        }
        with mock.patch.object(lun_cluster, "mutual_request", return_value=response) as request:
            result = lun_cluster.request_cluster_update(self.cluster, payload)
        self.assertTrue(result["complete"])
        self.assertEqual(request.call_args.args[2:5], (20000, "POST", "/v1/action"))
        self.assertEqual(request.call_args.args[5]["action"], "cluster.update-all")

    @unittest.skipUnless(shutil.which("openssl"), "OpenSSL is required")
    def test_cluster_update_targets_trusted_federation_members(self) -> None:
        first = self._federation_cluster("update-first", 27321)
        second = self._federation_cluster("update-second", 27322)
        try:
            first.federation_register_peer(second.federation_public_bundle())
            legacy_id = "d" * 32
            first.upsert_node({
                "node_id": legacy_id, "public_host": "192.0.2.44", "public_port": 27323,
                "internal_port": 27323, "api_version": 2, "location": {"country_code": "ZZ"},
            }, role="legacy-candidate")
            with first.db.connection:
                first.db.connection.execute(
                    "UPDATE nodes SET state='legacy-unverified' WHERE id=?", (legacy_id,)
                )
            script_payload, agent_payload = self._update_payloads()
            remote_id = second.load_config()["node_id"]
            calls: list[tuple[str, str]] = []

            def fake_send(_cluster, node_id, action, payload, timeout=900):
                calls.append((node_id, action))
                if action == "status.refresh":
                    return {"result": second.local_status()}
                return {"result": {"sha256": payload["sha256"]}}

            with mock.patch.object(lun_cluster, "send_action", side_effect=fake_send):
                result = lun_cluster.distribute_cluster_update(
                    first, {"script": script_payload, "agent": agent_payload}
                )
            self.assertEqual(calls, [
                (remote_id, "status.refresh"),
                (remote_id, "script.install"),
                (remote_id, "agent.install"),
            ])
            self.assertTrue(result["complete"])
            self.assertEqual(result["nodes"][str(first.node(remote_id)["server_number"])]["status"], "updated")
            self.assertNotIn(str(first.node(legacy_id)["server_number"]), result["nodes"])
            self.assertEqual(first.node(remote_id)["role"], "federation")
        finally:
            first.close()
            second.close()

    def test_cluster_update_marks_unresponsive_child_and_continues(self) -> None:
        master_id, child_id = "a" * 32, "b" * 32
        self.cluster.save_config({
            "enabled": True, "role": "master", "node_id": master_id,
            "public_host": "127.0.0.1", "public_port": 20000, "internal_port": 20000,
        })
        self.cluster.upsert_node({
            "node_id": master_id, "public_host": "127.0.0.1", "public_port": 20000,
            "internal_port": 20000, "api_version": 1, "location": {"country_code": "JP"},
        }, role="master")
        self.cluster.upsert_node({
            "node_id": child_id, "public_host": "127.0.0.1", "public_port": 21000,
            "internal_port": 21000, "api_version": 1, "location": {"country_code": "US"},
        }, role="child")
        script_payload, agent_payload = self._update_payloads()
        with mock.patch.object(lun_cluster, "send_action", side_effect=TimeoutError("handshake timeout")):
            result = lun_cluster.distribute_cluster_update(
                self.cluster, {"script": script_payload, "agent": agent_payload}
            )
        self.assertFalse(result["complete"])
        self.assertIn("handshake timeout", result["failures"]["2"])
        self.assertEqual(self.cluster.node(child_id)["state"], "unreachable")

    def test_cluster_update_installs_master_last_when_requested(self) -> None:
        master_id = "a" * 32
        self.cluster.save_config({
            "enabled": True, "role": "master", "node_id": master_id,
            "public_host": "127.0.0.1", "public_port": 20000, "internal_port": 20000,
        })
        self.cluster.upsert_node({
            "node_id": master_id, "public_host": "127.0.0.1", "public_port": 20000,
            "internal_port": 20000, "api_version": 1, "location": {"country_code": "JP"},
        }, role="master")
        script_payload, agent_payload = self._update_payloads()
        order: list[str] = []
        with mock.patch.object(
            lun_cluster, "install_script_payload", side_effect=lambda *_: order.append("script") or {}
        ), mock.patch.object(
            lun_cluster, "install_agent_payload", side_effect=lambda *_: order.append("agent") or {}
        ):
            result = lun_cluster.distribute_cluster_update(
                self.cluster, {"script": script_payload, "agent": agent_payload}, install_local=True
            )
        self.assertEqual(order, ["script", "agent"])
        self.assertTrue(result["restart_required"])
        self.assertEqual(result["local"]["status"], "updated")

    def test_database_replace_keeps_live_wal_connections_consistent(self) -> None:
        candidate_root = Path(self.temporary.name) / "candidate"
        candidate_root.mkdir()
        candidate = lun_cluster.Cluster(candidate_root)
        observer = lun_cluster.sqlite3.connect(self.cluster.db.path)
        try:
            candidate.db.set_setting("database-owner", "candidate")
            observer.execute("PRAGMA journal_mode=WAL")
            observer.execute("SELECT COUNT(*) FROM settings").fetchone()
            self.cluster.db.set_setting("database-owner", "old")
            self.cluster.replace_database(candidate.db.path)
            self.assertEqual(self.cluster.db.setting("database-owner"), "candidate")
            self.assertEqual(
                observer.execute("SELECT value FROM settings WHERE key='database-owner'").fetchone()[0],
                "candidate",
            )
            checker = lun_cluster.sqlite3.connect(self.cluster.db.path)
            try:
                self.assertEqual(checker.execute("PRAGMA quick_check").fetchone()[0], "ok")
            finally:
                checker.close()
        finally:
            observer.close()
            candidate.close()

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

    @unittest.skipUnless(shutil.which("openssl"), "OpenSSL is required")
    def test_federation_three_nodes_sync_events_and_rejects_tamper_replay(self) -> None:
        roots = [Path(self.temporary.name) / f"fed-{name}" for name in ("a", "b", "c")]
        clusters = []
        try:
            for number, root in enumerate(roots, 1):
                root.mkdir()
                (root / "uuid").write_text("11111111-1111-4111-8111-111111111111\n", encoding="utf-8")
                item = lun_cluster.Cluster(root)
                item.federation_init("127.0.0.1", 24000 + number, remark=f"node-{number}")
                clusters.append(item)
            first, second, third = clusters
            first.federation_register_peer(second.federation_public_bundle())
            first.federation_register_peer(third.federation_public_bundle())
            baseline = first.federation_public_bundle()
            second.import_federation_bundle(baseline, allow_cluster_adopt=True)
            third.import_federation_bundle(baseline, allow_cluster_adopt=True)
            first.create_event("node.metadata", "node:shared", {"value": "first"})
            second.create_event("node.metadata", "node:shared", {"value": "second"})
            all_events = [event for item in clusters for event in item.federation_events_since({})]
            for receiver in clusters:
                receiver.federation_import_events(all_events)
            states = [json.loads(item.db.connection.execute("SELECT payload FROM federation_entities WHERE entity_key='node:shared'").fetchone()[0]) for item in clusters]
            self.assertEqual(states[0], states[1])
            self.assertEqual(states[1], states[2])
            event = first.create_event("node.metadata", "node:tamper", {"value": "safe"})
            bad = dict(event)
            bad["payload"] = json.dumps({"value": "changed"})
            with self.assertRaises(lun_cluster.ClusterError):
                second.ingest_event(bad)
            self.assertTrue(second.ingest_event(event))
            self.assertFalse(second.ingest_event(event))  # replay is idempotent
        finally:
            for item in clusters:
                item.close()

    @unittest.skipUnless(shutil.which("openssl"), "OpenSSL is required")
    def test_federation_numbers_usage_revoke_and_private_free_backup(self) -> None:
        self.cluster.federation_init("127.0.0.1", 25001)
        local = self.cluster.load_config()["node_id"]
        second_root = Path(self.temporary.name) / "federation-second"
        second_root.mkdir()
        (second_root / "uuid").write_text("11111111-1111-4111-8111-111111111111\n", encoding="utf-8")
        second = lun_cluster.Cluster(second_root)
        try:
            second.federation_init("127.0.0.1", 25002)
            bundle = second.federation_public_bundle()
            self.cluster.federation_register_peer(bundle)
            self.assertEqual(self.cluster.node(local)["server_number"], 1)
            self.assertEqual(self.cluster.node(bundle["node_id"])["server_number"], 2)
            event = self.cluster.create_event("usage.absolute", "usage:device:2026-08", {
                "node_id": local, "device_uuid": "device", "epoch": "2026-08", "uplink": 10,
                "downlink": 20, "month_uplink": 5, "month_downlink": 6, "sequence": 2,
            })
            self.assertFalse(self.cluster.ingest_event(event))
            self.assertEqual(self.cluster.global_usage("device", "2026-08")["downlink"], 20)
            now = lun_cluster.utc_now()
            status = self.cluster.record_transport_failure(bundle["node_id"], when=now - 40)
            self.cluster.record_transport_failure(bundle["node_id"], when=now - 20)
            status = self.cluster.record_transport_failure(bundle["node_id"], when=now)
            self.assertTrue(status["needs_probe"])
            for offset in (40, 20, 0):
                vote = self.cluster.create_probe_vote(bundle["node_id"], False, observed_at=now - offset)
                verdict = self.cluster.record_probe_vote(vote)
            self.assertTrue(verdict["revocable"])
            forged = self.cluster.create_probe_vote(bundle["node_id"], False)
            forged["signature"] = base64.b64encode(b"forged").decode()
            with self.assertRaises(lun_cluster.ClusterError):
                self.cluster.record_probe_vote(forged)
            self.cluster.finalize_suspect(bundle["node_id"])
            self.assertTrue(self.cluster.federation_cleanup_plan(bundle["node_id"])["revoked"])
            backup = Path(self.temporary.name) / "federation.backup"
            self.cluster.export_federation_backup(backup, "correct-password")
            second_config = second.load_config().copy()
            second_key = (second.pki / "federation-root.key").read_bytes()
            second.import_federation_bundle(self.cluster.federation_public_bundle(), allow_cluster_adopt=True)
            second.restore_federation_backup(backup, "correct-password")
            self.assertEqual(second.load_config()["node_id"], second_config["node_id"])
            self.assertEqual((second.pki / "federation-root.key").read_bytes(), second_key)
        finally:
            second.close()

    @unittest.skipUnless(shutil.which("openssl"), "OpenSSL is required")
    def test_old_master_configuration_requires_and_supports_explicit_migration(self) -> None:
        self.cluster.init_master("127.0.0.1", 26001)
        with self.assertRaises(lun_cluster.ClusterError):
            self.cluster.federation_init("127.0.0.1", 26001)
        migrated = self.cluster.migrate_to_federation()
        self.assertEqual(migrated["mode"], "federation")
        self.assertEqual(migrated["role"], "federation")
        self.assertNotIn("controller_id", migrated)
        self.assertTrue((self.cluster.pki / "federation-root.key").exists())
        self.assertFalse((self.cluster.pki / "cluster-ca.key").exists())
        recovery = Path(migrated["legacy_rollback_archive"])
        self.assertTrue(recovery.is_file())
        with tarfile.open(recovery, "r:gz") as archive:
            self.assertIn("pki/cluster-ca.key", archive.getnames())

    @unittest.skipUnless(shutil.which("openssl"), "OpenSSL is required")
    def test_third_node_dependency_join_root_immutability_and_failed_pairing(self) -> None:
        first = self._federation_cluster("join-first", 27001)
        second = self._federation_cluster("join-second", 27002)
        third = self._federation_cluster("join-third", 27003)
        replacement = self._federation_cluster("join-replacement", 27004)
        try:
            first.federation_register_peer(second.federation_public_bundle())
            bundle = first.federation_public_bundle()
            bundle["events"] = list(reversed(bundle["events"]))
            unsigned = {key: value for key, value in bundle.items() if key != "signature"}
            bundle["signature"] = first._sign_federation(lun_cluster.json_dumps(unsigned).encode())
            third.import_federation_bundle(bundle, allow_cluster_adopt=True)
            self.assertIsNotNone(third.db.connection.execute(
                "SELECT 1 FROM federation_keys WHERE node_id=?", (second.load_config()["node_id"],)
            ).fetchone())
            with self.assertRaises(lun_cluster.ClusterError):
                first.register_federation_key(
                    second.load_config()["node_id"], replacement.federation_root_certificate(),
                    replacement.federation_identity_certificate(),
                )
            target_id = replacement.load_config()["node_id"]
            uri = lun_cluster.make_join_uri(
                "127.0.0.1", 27004, target_id, "x" * 43,
                replacement.certificate_fingerprint(), lun_cluster.utc_now() + 60,
            )
            with mock.patch.object(lun_cluster, "bootstrap_request", side_effect=[
                {"ok": True, "bundle": replacement.federation_public_bundle()},
                lun_cluster.ClusterError("remote transaction failed"),
                lun_cluster.ClusterError("transaction status unavailable"),
            ]):
                with self.assertRaises(lun_cluster.ClusterError):
                    lun_cluster.federation_add_peer(first, uri)
            self.assertIsNone(first.db.connection.execute(
                "SELECT 1 FROM federation_keys WHERE node_id=?", (target_id,)
            ).fetchone())
            pending = first.db.connection.execute(
                "SELECT status FROM federation_join_transactions WHERE direction='outgoing'"
            ).fetchone()
            self.assertEqual(pending["status"], "remote-committed-local-pending")
        finally:
            for item in (first, second, third, replacement):
                item.close()

    @unittest.skipUnless(shutil.which("openssl"), "OpenSSL is required")
    def test_member_number_conflicts_converge_in_forward_and_reverse_order(self) -> None:
        source = self._federation_cluster("number-source", 27101)
        second = self._federation_cluster("number-second", 27102)
        third = self._federation_cluster("number-third", 27103)
        identity_backup = Path(self.temporary.name) / "number-identity.backup"
        source.export_identity_backup(identity_backup, "correct-password")
        receivers = [self._blank_cluster("number-forward"), self._blank_cluster("number-reverse")]
        try:
            for receiver in receivers:
                receiver.restore_federation_backup(identity_backup, "correct-password")
            source.federation_register_peer(second.federation_public_bundle())
            source.federation_register_peer(third.federation_public_bundle())
            forward = source.federation_public_bundle()
            reverse = dict(forward)
            reverse["events"] = list(reversed(forward["events"]))
            reverse["signature"] = source._sign_federation(lun_cluster.json_dumps({
                key: value for key, value in reverse.items() if key != "signature"
            }).encode())
            receivers[0].import_federation_bundle(forward)
            receivers[1].import_federation_bundle(reverse)
            ids = [source.load_config()["node_id"], second.load_config()["node_id"], third.load_config()["node_id"]]
            mappings = [{node_id: int(receiver.node(node_id)["server_number"]) for node_id in ids} for receiver in receivers]
            self.assertEqual(mappings[0], mappings[1])
            self.assertEqual(len(set(mappings[0].values())), 3)
        finally:
            for item in (source, second, third, *receivers):
                item.close()

    @unittest.skipUnless(shutil.which("openssl"), "OpenSSL is required")
    def test_revocation_boundary_and_membership_proof_nonce(self) -> None:
        first = self._federation_cluster("revoke-first", 27201)
        second = self._federation_cluster("revoke-second", 27202)
        try:
            first.federation_register_peer(second.federation_public_bundle())
            second.import_federation_bundle(first.federation_public_bundle(), allow_cluster_adopt=True)
            before_one = second.create_event("node.metadata", "node:before-one", {"value": 1})
            before_two = second.create_event("node.metadata", "node:before-two", {"value": 2})
            first.create_event("member.revoke", f"member:{second.load_config()['node_id']}", {
                "node_id": second.load_config()["node_id"], "reason": "test", "revoked_after_seq": 3,
            })
            self.assertEqual(first.federation_import_events([before_two, before_one]), 2)
            after = second.create_event("node.metadata", "node:after", {"value": 3})
            with self.assertRaises(lun_cluster.ClusterError):
                first.federation_import_events([after])
            nonce = "proof_nonce_1234567890"
            proof = first.membership_status_proof(second.load_config()["node_id"], nonce)
            self.assertTrue(first.verify_membership_status_proof(
                proof, second.load_config()["node_id"], nonce
            ))
            with self.assertRaises(lun_cluster.ClusterError):
                first.verify_membership_status_proof(proof, second.load_config()["node_id"], "wrong_nonce_123456")
        finally:
            first.close()
            second.close()

    @unittest.skipUnless(shutil.which("openssl"), "OpenSSL is required")
    def test_data_backup_rejects_traversal_and_preserves_target_identity(self) -> None:
        source = self._federation_cluster("backup-source", 27301)
        target = self._federation_cluster("backup-target", 27302)
        try:
            join = target.create_join_code()
            token = lun_cluster.parse_join_uri(join)["token"]
            source_bundle = source.federation_public_bundle()
            transaction = source.create_join_transaction(source_bundle, target.load_config()["node_id"])
            target.accept_federation_join(token, source_bundle, transaction)
            backup = Path(self.temporary.name) / "data-only.backup"
            source.export_federation_backup(backup, "correct-password")
            old_config = target.config_path.read_bytes()
            old_key = (target.pki / "federation-root.key").read_bytes()
            target.restore_federation_backup(backup, "correct-password")
            self.assertEqual(target.config_path.read_bytes(), old_config)
            self.assertEqual((target.pki / "federation-root.key").read_bytes(), old_key)

            archive_bytes = io.BytesIO()
            with tarfile.open(fileobj=archive_bytes, mode="w:gz") as archive:
                info = tarfile.TarInfo("../escape")
                content = b"malicious"
                info.size = len(content)
                archive.addfile(info, io.BytesIO(content))
            malicious = Path(self.temporary.name) / "malicious.backup"
            source._encrypt_backup_payload(archive_bytes.getvalue(), malicious, "correct-password")
            with self.assertRaises(lun_cluster.ClusterError):
                target.restore_federation_backup(malicious, "correct-password")
        finally:
            source.close()
            target.close()

    @unittest.skipUnless(shutil.which("openssl"), "OpenSSL is required")
    def test_legacy_five_node_migration_is_local_only_and_candidates_are_inactive(self) -> None:
        self.cluster.init_master("127.0.0.1", 27401)
        local_id = self.cluster.load_config()["node_id"]
        (self.root / "jhsub.txt").write_text("vless://local\n", encoding="utf-8")
        legacy = [
            ("2" * 32, "192.0.2.2"), ("3" * 32, "198.51.100.3"),
            ("4" * 32, "203.0.113.4"), ("5" * 32, "192.0.2.5"),
        ]
        for index, (node_id, host) in enumerate(legacy, 2):
            self.cluster.upsert_node({"node_id": node_id, "public_host": host, "public_port": 20000 + index,
                                      "internal_port": 20000 + index, "api_version": 2,
                                      "location": {"country_code": "ZZ"}}, role="child")
        with mock.patch.object(lun_cluster, "mutual_request") as request, \
                mock.patch.object(lun_cluster, "bootstrap_request") as bootstrap, \
                mock.patch.object(lun_cluster.urllib.request, "urlopen") as urlopen:
            migrated = self.cluster.migrate_to_federation()
        request.assert_not_called()
        bootstrap.assert_not_called()
        urlopen.assert_not_called()
        self.assertEqual(self.cluster.node(local_id)["server_number"], 1)
        for index, (node_id, _) in enumerate(legacy, 2):
            row = self.cluster.node(node_id)
            self.assertEqual(row["server_number"], index)
            self.assertEqual(row["state"], "legacy-unverified")
            self.assertIsNone(self.cluster.db.connection.execute(
                "SELECT 1 FROM federation_keys WHERE node_id=?", (node_id,)
            ).fetchone())
            with mock.patch.object(lun_cluster, "mutual_request") as transport:
                with self.assertRaises(lun_cluster.ClusterError):
                    lun_cluster.federation_sync(self.cluster, node_id)
                with self.assertRaises(lun_cluster.ClusterError):
                    lun_cluster.send_action(self.cluster, node_id, "status.refresh", {})
                transport.assert_not_called()
        selected = self.cluster._selected_nodes("all", "legacy")
        self.assertEqual({row["id"] for row in selected}, {local_id})
        trust = {row["id"]: row["trusted"] for row in self.cluster.nodes()}
        self.assertTrue(trust[local_id])
        self.assertTrue(all(not trust[node_id] for node_id, _ in legacy))
        self.assertEqual(migrated["mode"], "federation")

    def test_cdn_pool_validation_preview_apply_and_rollback(self) -> None:
        (self.root / "cdnip").write_text("2.2.2.2 old.example.com\n", encoding="utf-8")
        (self.root / "cdnip1").write_text("stale.example.com\n", encoding="utf-8")
        (self.root / "cdnip9").write_text("stale-nine.example.com\n", encoding="utf-8")
        (self.root / "cdnym").write_text("host.example.com\n", encoding="utf-8")
        script = self.root / "lun.sh"
        script.write_text("#!/usr/bin/env bash\n", encoding="utf-8")

        preview = self.cluster.preview_cdn_pool(
            "merge", "1.1.1.1 2001:0db8::1 CDN.Example.COM. 1.1.1.1"
        )
        self.assertEqual(preview["current"], ["2.2.2.2", "old.example.com"])
        self.assertEqual(preview["source"], ["1.1.1.1", "2001:db8::1", "cdn.example.com"])
        self.assertEqual(preview["result"], [
            "1.1.1.1", "2001:db8::1", "cdn.example.com", "2.2.2.2", "old.example.com",
        ])
        replaced = self.cluster.preview_cdn_pool("replace", "1.1.1.1")
        self.assertEqual(replaced["remove"], ["2.2.2.2", "old.example.com"])
        for invalid in ("", "https://1.1.1.1", "1.1.1.1:443", "host.example/path", "$(id)"):
            with self.subTest(invalid=invalid), self.assertRaises(lun_cluster.ClusterError):
                self.cluster.normalize_cdn_pool(invalid)

        success = mock.Mock(returncode=0, stdout="ok", stderr="")
        with mock.patch.object(self.cluster, "_run", return_value=success) as runner, \
                mock.patch.object(self.cluster, "record_local_snapshot"):
            applied = self.cluster.apply_cdn_pool("replace", "1.1.1.1 edge.example.com", script)
        self.assertTrue(applied["applied"])
        runner.assert_called_once_with(
            ["bash", str(script), "subscription-refresh"], timeout=300, check=False
        )
        self.assertEqual((self.root / "cdnip").read_text(encoding="utf-8"), "1.1.1.1 edge.example.com\n")
        self.assertEqual((self.root / "cdnip2").read_text(encoding="utf-8"), "edge.example.com\n")
        self.assertFalse((self.root / "cdnip9").exists())
        self.assertEqual((self.root / "cdnym").read_text(encoding="utf-8"), "host.example.com\n")

        original = (self.root / "cdnip").read_bytes()
        failed = mock.Mock(returncode=1, stdout="", stderr="refresh failed")
        restored = mock.Mock(returncode=0, stdout="restored", stderr="")
        with mock.patch.object(self.cluster, "_run", side_effect=[failed, restored]) as runner:
            rollback = self.cluster.apply_cdn_pool("replace", "9.9.9.9", script)
        self.assertFalse(rollback["applied"])
        self.assertEqual(rollback["rollback"], {"restored": True, "refresh_returncode": 0})
        self.assertEqual((self.root / "cdnip").read_bytes(), original)
        self.assertEqual(runner.call_count, 2)

        with self.assertRaises(lun_cluster.ClusterError):
            lun_cluster.execute_action(self.cluster, {
                "request_id": "a" * 32, "action": "cdn.pool.preview",
                "payload": {"mode": "merge", "cfip": "1.1.1.1", "cdnym": "forbidden.example"},
            })

    def test_cdn_pool_remote_command_uses_structured_send_action(self) -> None:
        local_id, remote_id = "a" * 32, "b" * 32
        self.cluster.save_config({"enabled": True, "mode": "federation", "role": "federation",
                                  "node_id": local_id, "cluster_id": "c" * 32})
        self._add_node(local_id, "DE")
        self._add_node(remote_id, "JP")
        with mock.patch.object(lun_cluster, "send_action", return_value={"mode": "merge"}) as sender:
            result = lun_cluster.cdn_pool_command(
                self.cluster, remote_id, "merge", "1.1.1.1 edge.example.com", apply=False
            )
        self.assertEqual(result["mode"], "merge")
        sender.assert_called_once_with(
            self.cluster, remote_id, "cdn.pool.preview",
            {"mode": "merge", "cfip": "1.1.1.1 edge.example.com"},
        )

    def test_new_cli_contracts_and_cdn_json_output(self) -> None:
        parser = lun_cluster.build_parser()
        self.assertEqual(parser.parse_args([
            "identity-restore", "--path", "identity.backup", "--password-file", "password.txt",
        ]).command, "identity-restore")
        self.assertEqual(parser.parse_args([
            "subscription-access", "--token", "a" * 16,
        ]).command, "subscription-access")
        local_id = "a" * 32
        self.cluster.save_config({"enabled": True, "mode": "federation", "role": "federation",
                                  "node_id": local_id, "cluster_id": "b" * 32})
        self._add_node(local_id, "DE")
        (self.root / "cdnip").write_text("2.2.2.2\n", encoding="utf-8")
        output = io.StringIO()
        with contextlib.redirect_stdout(output):
            code = lun_cluster.main([
                "--root", str(self.root), "--json", "cdn-pool-preview", "--node-id", local_id,
                "--mode", "merge", "--cfip", "1.1.1.1",
            ])
        self.assertEqual(code, 0)
        payload = json.loads(output.getvalue())
        self.assertEqual(payload["result"], ["1.1.1.1", "2.2.2.2"])

    @unittest.skipUnless(shutil.which("openssl"), "OpenSSL is required")
    def test_identity_restore_rejects_data_backup_and_restores_identity(self) -> None:
        source = self._federation_cluster("identity-source", 27501)
        target = self._federation_cluster("identity-target", 27502)
        data_backup = Path(self.temporary.name) / "federation-data.backup"
        identity_backup = Path(self.temporary.name) / "identity.backup"
        try:
            source.export_federation_backup(data_backup, "correct-password")
            source.export_identity_backup(identity_backup, "correct-password")
            target_config = target.config_path.read_bytes()
            target_key = (target.pki / "federation-root.key").read_bytes()
            with self.assertRaisesRegex(lun_cluster.ClusterError, "只接受完整身份备份"):
                target.restore_identity_backup(data_backup, "correct-password")
            self.assertEqual(target.config_path.read_bytes(), target_config)
            self.assertEqual((target.pki / "federation-root.key").read_bytes(), target_key)

            restored = target.restore_identity_backup(identity_backup, "correct-password")
            self.assertTrue(restored["identity_restored"])
            self.assertEqual(target.load_config()["node_id"], source.load_config()["node_id"])
            self.assertEqual(
                (target.pki / "federation-root.key").read_bytes(),
                (source.pki / "federation-root.key").read_bytes(),
            )
        finally:
            source.close()
            target.close()

    @unittest.skipUnless(shutil.which("openssl"), "OpenSSL is required")
    def test_subscription_access_debounce_failures_and_untrusted_exclusion(self) -> None:
        first = self._federation_cluster("access-first", 27601)
        second = self._federation_cluster("access-second", 27602)
        third = self._federation_cluster("access-third", 27603)
        try:
            first.federation_register_peer(second.federation_public_bundle())
            first.federation_register_peer(third.federation_public_bundle())
            legacy_id = "d" * 32
            first.upsert_node({"node_id": legacy_id, "public_host": "192.0.2.44", "public_port": 24444,
                               "internal_port": 24444, "api_version": 2,
                               "location": {"country_code": "ZZ"}}, role="legacy-candidate")
            with first.db.connection:
                first.db.connection.execute(
                    "UPDATE nodes SET state='legacy-unverified' WHERE id=?", (legacy_id,)
                )
            token = first.profiles()[0]["token"]
            calls: list[str] = []

            def fake_sync(_cluster, node_id):
                calls.append(node_id)
                if node_id == second.load_config()["node_id"]:
                    raise lun_cluster.ClusterError("offline")
                return {"received": 4}

            with mock.patch.object(lun_cluster, "federation_sync", side_effect=fake_sync), \
                    mock.patch.object(first, "refresh_profiles", return_value=[{"id": 1}]) as refresh:
                result = first.subscription_access(token, now=1000)
                debounced = first.subscription_access(token, now=1020)
            self.assertFalse(result["debounced"])
            self.assertEqual(len(result["failures"]), 1)
            self.assertEqual(sum(result["received"].values()), 4)
            self.assertTrue(debounced["debounced"])
            self.assertNotIn(legacy_id, calls)
            self.assertEqual(set(calls), {
                second.load_config()["node_id"], third.load_config()["node_id"],
            })
            refresh.assert_called_once_with()
            settings = [tuple(row) for row in first.db.connection.execute(
                "SELECT key,value FROM settings WHERE key LIKE 'subscription.access.%'"
            )]
            self.assertEqual(settings, [("subscription.access." + lun_cluster.hashlib.sha256(token.encode()).hexdigest(), "1000")])
            self.assertNotIn(token, json.dumps(settings))
            with first.db.connection:
                first.db.connection.execute("UPDATE profiles SET enabled=0 WHERE token=?", (token,))
            with self.assertRaises(lun_cluster.ClusterError):
                first.subscription_access(token, now=1040)
        finally:
            first.close()
            second.close()
            third.close()

    def test_serve_starts_subscription_catchup_only_once(self) -> None:
        self.cluster.save_config({"enabled": True, "role": "master", "node_id": "a" * 32,
                                  "cluster_id": "b" * 32, "bind": "127.0.0.1",
                                  "internal_port": 27701, "public_port": 27701})
        started: list[str] = []

        class FakeServer:
            def __init__(self, *_args):
                self.socket = object()
                self.restart_requested = False

            def serve_forever(self, **_kwargs):
                return None

            def server_close(self):
                return None

        class FakeThread:
            def __init__(self, *, target, daemon):
                self.target = target
                self.daemon = daemon

            def start(self):
                started.append(self.target.__name__)
                if self.target.__name__ == "initial_subscription_catchup":
                    self.target()

        context = mock.Mock()
        context.wrap_socket.return_value = object()
        with mock.patch.object(lun_cluster, "ThreadingClusterServer", FakeServer), \
                mock.patch.object(lun_cluster, "server_context", return_value=context), \
                mock.patch.object(lun_cluster.threading, "Thread", FakeThread), \
                mock.patch.object(lun_cluster.signal, "signal"), \
                mock.patch.object(self.cluster, "subscription_catchup", return_value={}) as catchup:
            lun_cluster.serve(self.cluster)
        catchup.assert_called_once_with()
        self.assertEqual(started.count("initial_subscription_catchup"), 1)

    def test_serve_restart_request_exits_for_service_supervisor(self) -> None:
        self.cluster.save_config({"enabled": True, "role": "master", "node_id": "a" * 32,
                                  "cluster_id": "b" * 32, "bind": "127.0.0.1",
                                  "internal_port": 27702, "public_port": 27702})

        class FakeServer:
            def __init__(self, *_args):
                self.socket = object()
                self.restart_requested = False

            def serve_forever(self, **_kwargs):
                self.restart_requested = True

            def server_close(self):
                return None

        class FakeThread:
            def __init__(self, *, target, daemon):
                self.target = target
                self.daemon = daemon

            def start(self):
                return None

        context = mock.Mock()
        context.wrap_socket.return_value = object()
        with mock.patch.object(lun_cluster, "ThreadingClusterServer", FakeServer), \
                mock.patch.object(lun_cluster, "server_context", return_value=context), \
                mock.patch.object(lun_cluster.threading, "Thread", FakeThread), \
                mock.patch.object(lun_cluster.signal, "signal"):
            with self.assertRaises(SystemExit) as raised:
                lun_cluster.serve(self.cluster)
        self.assertEqual(raised.exception.code, lun_cluster.RESTART_EXIT_CODE)

    @unittest.skipUnless(shutil.which("openssl"), "OpenSSL is required")
    def test_pairing_invalid_final_bundle_keeps_signed_recoverable_transaction(self) -> None:
        first = self._federation_cluster("transaction-first", 27801)
        remote = self._federation_cluster("transaction-remote", 27802)
        join_uri = remote.create_join_code()
        join = lun_cluster.parse_join_uri(join_uri)
        committed: dict[str, object] = {}
        try:
            def first_attempt(_join, method, path, body=None):
                if method == "GET":
                    return {"ok": True, "bundle": remote.federation_public_bundle()}
                if path == "/v1/federation/join":
                    accepted = remote.accept_federation_join(body["token"], body["bundle"], body["transaction"])
                    committed.update(accepted)
                    bad = dict(accepted["bundle"])
                    bad["signature"] = base64.b64encode(b"bad").decode()
                    return {"ok": True, "transaction_id": accepted["transaction_id"], "bundle": bad}
                raise lun_cluster.ClusterError("temporary status outage")

            with mock.patch.object(lun_cluster, "bootstrap_request", side_effect=first_attempt):
                with self.assertRaisesRegex(lun_cluster.ClusterError, "可恢复事务"):
                    lun_cluster.federation_add_peer(first, join_uri)
            remote_id = remote.load_config()["node_id"]
            self.assertIsNone(first.db.connection.execute(
                "SELECT 1 FROM federation_keys WHERE node_id=?", (remote_id,)
            ).fetchone())
            pending = first.db.connection.execute(
                "SELECT * FROM federation_join_transactions WHERE direction='outgoing'"
            ).fetchone()
            self.assertEqual(pending["status"], "remote-committed-local-pending")
            transaction = json.loads(pending["transaction_payload"])
            self.assertTrue(first._verify_federation_signature(
                first.federation_root_certificate(), first.canonical_join_transaction(transaction),
                transaction["signature"],
            ))

            def recovered(_join, method, path, body=None):
                self.assertEqual(path, "/v1/federation/join-status")
                return {"ok": True, **remote.federation_join_status(body["token"], body["transaction"])}

            with mock.patch.object(lun_cluster, "bootstrap_request", side_effect=recovered):
                result = lun_cluster.federation_add_peer(first, join_uri)
            self.assertTrue(result["recovered"])
            self.assertIsNotNone(first.db.connection.execute(
                "SELECT 1 FROM federation_keys WHERE node_id=?", (remote_id,)
            ).fetchone())
            self.assertEqual(first.db.connection.execute(
                "SELECT status FROM federation_join_transactions WHERE transaction_id=?",
                (result["transaction_id"],),
            ).fetchone()[0], "committed")
        finally:
            first.close()
            remote.close()

    @unittest.skipUnless(shutil.which("openssl"), "OpenSSL is required")
    def test_pairing_confirmation_allows_third_member_to_import_full_roster(self) -> None:
        first = self._federation_cluster("pair-confirm-first", 27811)
        second = self._federation_cluster("pair-confirm-second", 27812)
        third = self._federation_cluster("pair-confirm-third", 27813)
        join_uri = second.create_join_code()
        try:
            def paired(_join, method, path, body=None):
                if method == "GET":
                    return {"ok": True, "bundle": second.federation_public_bundle()}
                accepted = second.accept_federation_join(
                    body["token"], body["bundle"], body["transaction"]
                )
                return {"ok": True, "transaction_id": accepted["transaction_id"],
                        "bundle": accepted["bundle"]}

            with mock.patch.object(lun_cluster, "bootstrap_request", side_effect=paired):
                lun_cluster.federation_add_peer(first, join_uri)
            first_id = first.load_config()["node_id"]
            second_id = second.load_config()["node_id"]
            confirmation = first.db.connection.execute(
                "SELECT 1 FROM federation_events WHERE author_id=? AND type='member.upsert' "
                "AND entity_key=?",
                (first_id, f"member:{second_id}"),
            ).fetchone()
            self.assertIsNotNone(confirmation)
            third.import_federation_bundle(first.federation_public_bundle(), allow_cluster_adopt=True)
            self.assertIsNotNone(third.db.connection.execute(
                "SELECT 1 FROM federation_keys WHERE node_id=? AND revoked_at=0", (second_id,)
            ).fetchone())
        finally:
            first.close()
            second.close()
            third.close()

    @unittest.skipUnless(shutil.which("openssl"), "OpenSSL is required")
    def test_federation_profile_tokens_converge_and_old_urls_are_removed(self) -> None:
        first = self._federation_cluster("profile-first", 27821)
        second = self._federation_cluster("profile-second", 27822)
        try:
            first.federation_register_peer(second.federation_public_bundle())
            second.import_federation_bundle(first.federation_public_bundle(), allow_cluster_adopt=True)
            original = {cluster.load_config()["node_id"]: cluster.profiles()[0]["token"]
                        for cluster in (first, second)}
            self.assertEqual(len(set(original.values())), 2)
            for cluster in (first, second):
                token = original[cluster.load_config()["node_id"]]
                for directory in (cluster.cache / token, cluster.root.parent / "weblun" / token):
                    directory.mkdir(parents=True, exist_ok=True)
                    (directory / "jhsub.txt").write_text("old", encoding="utf-8")
                cluster.refresh_profiles()
            first_bundle = first.federation_public_bundle()
            second_bundle = second.federation_public_bundle()
            first.import_federation_bundle(second_bundle)
            second.import_federation_bundle(first_bundle)
            current = {cluster.load_config()["node_id"]: cluster.profiles()[0]["token"]
                       for cluster in (first, second)}
            self.assertEqual(len(set(current.values())), 1)
            for cluster in (first, second):
                node_id = cluster.load_config()["node_id"]
                if original[node_id] != current[node_id]:
                    self.assertFalse((cluster.cache / original[node_id]).exists())
                    self.assertFalse((cluster.root.parent / "weblun" / original[node_id]).exists())
            self.assertEqual(first.publish_local_profile_events()["events"], 0)
            self.assertEqual(second.publish_local_profile_events()["events"], 0)
        finally:
            first.close()
            second.close()

    @unittest.skipUnless(shutil.which("openssl"), "OpenSSL is required")
    def test_federation_user_events_converge_delete_and_keep_stable_device_key(self) -> None:
        first = self._federation_cluster("users-first", 27901)
        second = self._federation_cluster("users-second", 27902)
        third = self._federation_cluster("users-third", 27903)
        try:
            first.federation_register_peer(second.federation_public_bundle())
            first.federation_register_peer(third.federation_public_bundle())
            baseline = first.federation_public_bundle()
            second.import_federation_bundle(baseline, allow_cluster_adopt=True)
            third.import_federation_bundle(baseline, allow_cluster_adopt=True)
            node_ids = [item.load_config()["node_id"] for item in (first, second, third)]
            first.assign_user_nodes(7, node_ids)
            database = first.root / "modules" / "multiuser" / "data" / "lun.db"
            database.parent.mkdir(parents=True)
            sqlite3.connect(database).close()
            bundle = self._sample_federation_user_bundle()
            with mock.patch.object(lun_cluster, "export_master_users", return_value=bundle):
                published = first.publish_local_user_events()
            self.assertEqual(published["events"], 6)
            for receiver in (second, third):
                events = first.federation_events_since(receiver.federation_manifest())
                self.assertEqual(receiver.federation_import_events(reversed(events)), 6)
                self.assertEqual(receiver.federation_import_events(events), 0)

            captured: list[dict[str, object]] = []
            with mock.patch.object(second, "_apply_federation_user_bundle",
                                   side_effect=lambda value: captured.append(value) or {"users": 1}), \
                    mock.patch.object(second, "refresh_profiles", return_value=[]):
                applied = second.apply_federation_users()
            self.assertEqual(applied["users"], 1)
            imported_user = captured[-1]["users"][0]
            self.assertEqual(imported_user["monthly_quota"], 98765432)
            self.assertEqual(imported_user["permissions"], {"vl": True, "ss": False})
            self.assertEqual([item["key"] for item in imported_user["devices"]], [
                "00000000-0000-4000-8000-000000000001",
                "00000000-0000-4000-8000-000000000002",
            ])
            self.assertEqual(imported_user["devices"][1]["token"], "token_02_abcdefghijklmnop")

            one_device = self._sample_federation_user_bundle()
            one_device["users"][0]["devices"] = [one_device["users"][0]["devices"][1]]
            with mock.patch.object(lun_cluster, "export_master_users", return_value=one_device):
                self.assertGreater(first.publish_local_user_events()["events"], 0)
            delta = first.federation_events_since(second.federation_manifest())
            second.federation_import_events(reversed(delta))
            captured.clear()
            with mock.patch.object(second, "_apply_federation_user_bundle",
                                   side_effect=lambda value: captured.append(value) or {"users": 1}), \
                    mock.patch.object(second, "refresh_profiles", return_value=[]):
                second.apply_federation_users()
            remaining = captured[-1]["users"][0]["devices"]
            self.assertEqual([(item["key"], item["token"]) for item in remaining], [
                ("00000000-0000-4000-8000-000000000002", "token_02_abcdefghijklmnop")
            ])

            user_key = first._federation_user_key(node_ids[0], "7")
            base_payload = json.loads(first.db.connection.execute(
                "SELECT payload FROM federation_entities WHERE entity_key=?", ("user:" + user_key,)
            ).fetchone()[0])
            event_two = second.create_event("user.upsert", "user:" + user_key,
                                            {**base_payload, "name": "from-second"})
            event_three = third.create_event("user.upsert", "user:" + user_key,
                                             {**base_payload, "name": "from-third"})
            for receiver in (first, second, third):
                receiver.federation_import_events([event_three, event_two])
            winner = max((event_two, event_three), key=first._event_sort_key)
            expected_name = json.loads(winner["payload"])["name"]
            self.assertEqual({json.loads(item.db.connection.execute(
                "SELECT payload FROM federation_entities WHERE entity_key=?", ("user:" + user_key,)
            ).fetchone()[0])["name"] for item in (first, second, third)}, {expected_name})

            with mock.patch.object(lun_cluster, "export_master_users",
                                   return_value={"schema_version": 1, "users": []}):
                first.publish_local_user_events()
            deletion_events = first.federation_events_since(second.federation_manifest())
            second.federation_import_events(reversed(deletion_events))
            captured.clear()
            with mock.patch.object(second, "_apply_federation_user_bundle",
                                   side_effect=lambda value: captured.append(value) or {"users": 0}), \
                    mock.patch.object(second, "refresh_profiles", return_value=[]):
                second.apply_federation_users()
            self.assertEqual(captured[-1]["users"], [])
            self.assertEqual(second.db.connection.execute(
                "SELECT deleted FROM federation_entities WHERE entity_key=?", ("user:" + user_key,)
            ).fetchone()[0], 1)
            audit = json.dumps([dict(row) for row in first.db.connection.execute("SELECT * FROM audit_log")])
            self.assertNotIn("token_02_abcdefghijklmnop", audit)
            self.assertNotIn("password-2-secure", audit)
        finally:
            first.close()
            second.close()
            third.close()

    @unittest.skipUnless(shutil.which("openssl"), "OpenSSL is required")
    def test_migration_publishes_existing_users_and_rolls_back_publish_failure(self) -> None:
        self.cluster.init_master("127.0.0.1", 27911)
        local_id = self.cluster.load_config()["node_id"]
        self.cluster.assign_user_nodes(7, [local_id])
        database = self.root / "modules" / "multiuser" / "data" / "lun.db"
        database.parent.mkdir(parents=True)
        sqlite3.connect(database).close()
        with mock.patch.object(lun_cluster, "export_master_users",
                               return_value=self._sample_federation_user_bundle()):
            migrated = self.cluster.migrate_to_federation()
        self.assertEqual(migrated["migrated_users"]["users"], 1)
        event_types = {row[0] for row in self.cluster.db.connection.execute(
            "SELECT type FROM federation_events"
        )}
        self.assertTrue({"user.upsert", "device.upsert", "authorization.upsert", "token.upsert"} <= event_types)
        token_payload = json.loads(self.cluster.db.connection.execute(
            "SELECT payload FROM federation_entities WHERE type='token.upsert' ORDER BY entity_key LIMIT 1"
        ).fetchone()[0])
        self.assertEqual(token_payload["token"], "token_01_abcdefghijklmnop")
        authorization = json.loads(self.cluster.db.connection.execute(
            "SELECT payload FROM federation_entities WHERE type='authorization.upsert' LIMIT 1"
        ).fetchone()[0])
        self.assertEqual(authorization["nodes"], [local_id])

        failed = self._blank_cluster("migration-failure")
        try:
            failed.init_master("127.0.0.1", 27912)
            failed_db = failed.root / "modules" / "multiuser" / "data" / "lun.db"
            failed_db.parent.mkdir(parents=True)
            sqlite3.connect(failed_db).close()
            old_config = failed.config_path.read_bytes()
            old_ca = (failed.pki / "cluster-ca.key").read_bytes()
            with mock.patch.object(failed, "publish_local_user_events",
                                   side_effect=lun_cluster.ClusterError("publish failed")):
                with self.assertRaisesRegex(lun_cluster.ClusterError, "publish failed"):
                    failed.migrate_to_federation()
            self.assertEqual(failed.config_path.read_bytes(), old_config)
            self.assertEqual((failed.pki / "cluster-ca.key").read_bytes(), old_ca)
            self.assertEqual(failed.load_config()["role"], "master")
        finally:
            failed.close()

    @unittest.skipUnless(shutil.which("openssl"), "OpenSSL is required")
    def test_failure_coordinator_jitter_two_node_and_three_node_majority(self) -> None:
        first = self._federation_cluster("health-first", 27921)
        second = self._federation_cluster("health-second", 27922)
        try:
            first.federation_register_peer(second.federation_public_bundle())
            second_id = second.load_config()["node_id"]
            with mock.patch.object(lun_cluster, "mutual_request",
                                   side_effect=lun_cluster.FederationTransportError("offline")) as transport, \
                    mock.patch.object(first, "_coordinate_after_failures",
                                      return_value={"revoked": False, "state": "suspect"}) as coordinate:
                with self.assertRaises(lun_cluster.FederationTransportError):
                    lun_cluster.federation_sync(first, second_id)
            self.assertEqual(transport.call_count, 3)
            coordinate.assert_called_once()
            outcomes = iter((False, True))
            recovered = first.coordinate_member_health(second_id, probe=lambda *_: next(outcomes))
            self.assertFalse(recovered["revoked"])
            self.assertEqual(first.db.connection.execute(
                "SELECT COUNT(*) FROM federation_failures WHERE candidate_id=?", (second_id,)
            ).fetchone()[0], 0)
            forged = second.create_probe_vote(first.load_config()["node_id"], False)
            forged["signature"] = base64.b64encode(b"forged").decode()
            with self.assertRaises(lun_cluster.ClusterError):
                first.record_probe_vote(forged)
            verdict = first.coordinate_member_health(second_id, probe=lambda *_: False)
            self.assertTrue(verdict["revoked"])
            self.assertEqual(verdict["unreachable_votes"], 3)
        finally:
            first.close()
            second.close()

        first = self._federation_cluster("majority-first", 27923)
        candidate = self._federation_cluster("majority-candidate", 27924)
        voter = self._federation_cluster("majority-voter", 27925)
        try:
            first.federation_register_peer(candidate.federation_public_bundle())
            first.federation_register_peer(voter.federation_public_bundle())
            candidate_id = candidate.load_config()["node_id"]
            with mock.patch.object(lun_cluster, "mutual_request",
                                   side_effect=lun_cluster.FederationTransportError("partition")):
                insufficient = first.coordinate_member_health(candidate_id, probe=lambda *_: False)
            self.assertFalse(insufficient["revoked"])
            self.assertEqual(insufficient["unreachable_votes"], 1)
            first.record_transport_success(candidate_id)

            def witness(_cluster, _host, _port, method, path, body=None, timeout=30):
                self.assertEqual((method, path), ("POST", "/v1/federation/probe"))
                return {"vote": voter.create_probe_vote(candidate_id, False, nonce=body["nonce"])}

            with mock.patch.object(lun_cluster, "mutual_request", side_effect=witness):
                majority = first.coordinate_member_health(candidate_id, probe=lambda *_: False)
            self.assertTrue(majority["revoked"])
            self.assertEqual(majority["unreachable_votes"], 2)
        finally:
            first.close()
            candidate.close()
            voter.close()

    @unittest.skipUnless(shutil.which("openssl"), "OpenSSL is required")
    def test_member_and_user_tombstones_are_monotonic_in_both_orders(self) -> None:
        peer = self._federation_cluster("tombstone-peer", 27931)
        try:
            self.cluster.federation_init("127.0.0.1", 27930)
            bundle = peer.federation_public_bundle()
            self.cluster.federation_register_peer(bundle)
            peer_id = peer.load_config()["node_id"]
            member_payload = self.cluster.federation_member_payload(
                peer.local_status(), peer.federation_root_certificate(),
                peer.federation_identity_certificate(), False,
            )

            def signed(event_type, entity_key, payload, lamport, suffix):
                event = {
                    "author_id": self.cluster.load_config()["node_id"], "author_seq": suffix,
                    "prev_hash": "", "lamport": lamport, "type": event_type,
                    "entity_key": entity_key, "payload": lun_cluster.json_dumps(payload),
                    "created_at": lun_cluster.utc_now(),
                }
                event["signature"] = self.cluster._sign_federation(lun_cluster.canonical_event_fields(event))
                event["event_id"] = lun_cluster.event_hash(event)
                self.assertTrue(self.cluster._verify_federation_signature(
                    self.cluster.federation_root_certificate(), lun_cluster.canonical_event_fields(event),
                    event["signature"],
                ))
                return event

            high_upsert = signed("member.upsert", "member:" + peer_id, member_payload, 100, 10)
            low_revoke = signed("member.revoke", "member:" + peer_id,
                                {"node_id": peer_id, "revoked_after_seq": 1, "reason": "test"}, 1, 11)
            self.cluster._apply_federation_entity(high_upsert, member_payload)
            self.cluster._apply_federation_entity(low_revoke, json.loads(low_revoke["payload"]))
            self.assertEqual(self.cluster.db.connection.execute(
                "SELECT deleted FROM federation_entities WHERE entity_key=?", ("member:" + peer_id,)
            ).fetchone()[0], 1)
            self.cluster._apply_federation_entity(high_upsert, member_payload)
            self.assertNotEqual(self.cluster.db.connection.execute(
                "SELECT revoked_at FROM federation_keys WHERE node_id=?", (peer_id,)
            ).fetchone()[0], 0)

            owner = self.cluster.load_config()["node_id"]
            user_key = self.cluster._federation_user_key(owner, "9")
            user_payload = {"owner_id": owner, "user_key": user_key, "source_key": "9", "name": "user",
                            "manual_disabled": False, "lifetime_quota": 0, "monthly_quota": 1,
                            "reset_day": 1, "expires_at": None, "max_devices": 1}
            user_upsert = signed("user.upsert", "user:" + user_key, user_payload, 200, 12)
            user_delete_payload = {"owner_id": owner, "user_key": user_key}
            user_delete = signed("user.delete", "user:" + user_key, user_delete_payload, 2, 13)
            for order in ((user_upsert, user_delete), (user_delete, user_upsert)):
                with self.cluster.db.connection:
                    self.cluster.db.connection.execute(
                        "DELETE FROM federation_entities WHERE entity_key=?", ("user:" + user_key,)
                    )
                for event in order:
                    self.cluster._apply_federation_entity(event, json.loads(event["payload"]))
                row = self.cluster.db.connection.execute(
                    "SELECT type,deleted FROM federation_entities WHERE entity_key=?", ("user:" + user_key,)
                ).fetchone()
                self.assertEqual((row["type"], row["deleted"]), ("user.delete", 1))
        finally:
            peer.close()

    @unittest.skipUnless(shutil.which("openssl"), "OpenSSL is required")
    def test_revoked_self_cleanup_replay_rollback_and_new_identity(self) -> None:
        local = self._federation_cluster("cleanup-local", 27941)
        survivor = self._federation_cluster("cleanup-survivor", 27942)
        try:
            local.federation_register_peer(survivor.federation_public_bundle())
            survivor.import_federation_bundle(local.federation_public_bundle(), allow_cluster_adopt=True)
            local_id = local.load_config()["node_id"]
            nonce = "clean_non_revoked_nonce_123"
            live_proof = survivor.membership_status_proof(local_id, nonce)
            self.assertTrue(local.verify_membership_status_proof(live_proof, local_id, nonce, consume=True))
            with self.assertRaises(lun_cluster.ClusterError):
                local.verify_membership_status_proof(live_proof, local_id, nonce, consume=True)
            survivor.revoke_member(local_id, "test")
            marker = local.root / "ordinary-local-data.txt"
            marker.write_text("keep-me", encoding="utf-8")
            (local.root / "xr.json").write_text('{"inbounds": []}\n', encoding="utf-8")
            old_number = int(local.load_config()["server_number"])
            with mock.patch.object(local, "check_self_revocation", return_value={"cleaned": True}), \
                    mock.patch.object(lun_cluster, "ThreadingClusterServer") as preflight_listener:
                lun_cluster.serve(local)
            preflight_listener.assert_not_called()

            def forged(_peer, proof_nonce):
                proof = survivor.membership_status_proof(local_id, proof_nonce)
                proof["signature"] = base64.b64encode(b"forged").decode()
                return {"proof": proof}

            rejected = local.check_self_revocation(query=forged)
            self.assertFalse(rejected["cleaned"])
            self.assertTrue(local.is_federation())

            cleaned = local.check_self_revocation(query=lambda _peer, proof_nonce: {
                "proof": survivor.membership_status_proof(local_id, proof_nonce)
            })
            self.assertTrue(cleaned["cleaned"])
            self.assertEqual(marker.read_text(encoding="utf-8"), "keep-me")
            self.assertTrue((local.root / "xr.json").is_file())
            self.assertFalse((local.pki / "federation-root.key").exists())
            self.assertFalse(local.load_config()["enabled"])
            with mock.patch.object(lun_cluster, "ThreadingClusterServer") as listener:
                lun_cluster.serve(local)
            listener.assert_not_called()
            new_config = local.federation_init("127.0.0.1", 27943)
            self.assertNotEqual(new_config["node_id"], local_id)
            self.assertNotEqual(int(new_config["server_number"]), old_number)
        finally:
            local.close()
            survivor.close()

        local = self._federation_cluster("rollback-local", 27944)
        survivor = self._federation_cluster("rollback-survivor", 27945)
        held: sqlite3.Connection | None = None
        try:
            local.federation_register_peer(survivor.federation_public_bundle())
            survivor.import_federation_bundle(local.federation_public_bundle(), allow_cluster_adopt=True)
            local_id = local.load_config()["node_id"]
            survivor.revoke_member(local_id, "test rollback")
            multi_db = local.root / "modules" / "multiuser" / "data" / "lun.db"
            multi_db.parent.mkdir(parents=True)
            held = sqlite3.connect(multi_db)
            held.execute("CREATE TABLE marker(value TEXT)")
            held.execute("INSERT INTO marker VALUES('ordinary')")
            held.commit()
            old_config = local.config_path.read_bytes()
            old_key = (local.pki / "federation-root.key").read_bytes()

            def mutate(_bundle):
                writer = sqlite3.connect(multi_db)
                try:
                    writer.execute("UPDATE marker SET value='changed'")
                    writer.commit()
                finally:
                    writer.close()
                return {"users": 0}

            proof_nonce = "cleanup_rollback_nonce_123"
            proof = survivor.membership_status_proof(local_id, proof_nonce)
            with mock.patch.object(local, "_apply_federation_user_bundle", side_effect=mutate), \
                    mock.patch.object(local, "_after_revoked_cleanup_reset",
                                      side_effect=lun_cluster.ClusterError("injected cleanup failure")):
                with self.assertRaisesRegex(lun_cluster.ClusterError, "injected cleanup failure"):
                    local.exit_revoked_federation(proof, proof_nonce)
            self.assertEqual(local.config_path.read_bytes(), old_config)
            self.assertEqual((local.pki / "federation-root.key").read_bytes(), old_key)
            self.assertEqual(held.execute("SELECT value FROM marker").fetchone()[0], "ordinary")
        finally:
            if held is not None:
                held.close()
            local.close()
            survivor.close()

    @unittest.skipUnless(shutil.which("openssl"), "OpenSSL is required")
    def test_public_membership_status_works_without_client_cert_but_control_requires_mtls(self) -> None:
        first_port, second_port = free_port(), free_port()
        first = self._federation_cluster("tls-first", first_port)
        second = self._federation_cluster("tls-second", second_port)
        server = None
        thread = None
        try:
            first.federation_register_peer(second.federation_public_bundle())
            second.import_federation_bundle(first.federation_public_bundle(), allow_cluster_adopt=True)
            first_id = first.load_config()["node_id"]
            second_id = second.load_config()["node_id"]
            second.revoke_member(first_id, "tls test")
            server = lun_cluster.ThreadingClusterServer(("127.0.0.1", second_port), lun_cluster.ClusterHandler)
            server.cluster = second
            server.restart_requested = False
            server.socket = lun_cluster.server_context(second).wrap_socket(server.socket, server_side=True)
            thread = threading.Thread(target=server.serve_forever, daemon=True)
            thread.start()
            peer = dict(first.node(second_id))
            nonce = "public_tls_nonce_123456"
            response = lun_cluster.membership_status_request(first, peer, first_id, nonce)
            self.assertTrue(response["proof"]["revoked"])
            self.assertTrue(first.verify_membership_status_proof(response["proof"], first_id, nonce))

            context = ssl.create_default_context(ssl.Purpose.SERVER_AUTH,
                                                 cadata=second.federation_root_certificate())
            context.check_hostname = False
            connection = lun_cluster.http.client.HTTPSConnection(
                "127.0.0.1", second_port, context=context, timeout=5
            )
            try:
                connection.request("GET", "/v1/status")
                controlled = connection.getresponse()
                controlled.read()
                self.assertEqual(controlled.status, 403)
            finally:
                connection.close()
            with self.assertRaises(lun_cluster.FederationTransportError):
                lun_cluster.mutual_request(first, "127.0.0.1", second_port, "GET", "/v1/status")
        finally:
            if server is not None:
                server.shutdown()
                server.server_close()
            if thread is not None:
                thread.join(timeout=5)
            first.close()
            second.close()

    def _blank_cluster(self, name: str) -> object:
        root = Path(self.temporary.name) / name
        root.mkdir()
        (root / "uuid").write_text("11111111-1111-4111-8111-111111111111\n", encoding="utf-8")
        return lun_cluster.Cluster(root)

    @staticmethod
    def _sample_federation_user_bundle(device_count: int = 2) -> dict[str, object]:
        devices = [
            {
                "name": f"device-{index}",
                "uuid": f"00000000-0000-4000-8000-{index:012d}",
                "password": f"password-{index}-secure",
                "ss_password": f"ss-password-{index}-secure",
                "token": f"token_{index:02d}_abcdefghijklmnop",
                "enabled": True,
            }
            for index in range(1, device_count + 1)
        ]
        return {"schema_version": 1, "users": [{
            "key": "7", "name": "federation-user", "manual_disabled": False,
            "lifetime_quota": 123456789, "monthly_quota": 98765432,
            "reset_day": 3, "expires_at": 2_000_000_000, "max_devices": max(2, device_count),
            "devices": devices, "permissions": {"vl": True, "ss": False},
        }]}

    def _federation_cluster(self, name: str, port: int):
        cluster = self._blank_cluster(name)
        cluster.federation_init("127.0.0.1", port, remark=name)
        return cluster

    def _add_node(self, node_id: str, country: str) -> None:
        self.cluster.upsert_node({
            "node_id": node_id, "public_host": "127.0.0.1", "public_port": 20000,
            "internal_port": 20000, "api_version": 1,
            "location": {"country_code": country},
        })

    @staticmethod
    def _update_payloads() -> tuple[dict[str, str], dict[str, str]]:
        script = b"#!/usr/bin/env bash\n# V26.8.8.3\nexit 0\n"
        agent = b"#!/usr/bin/env python3\nVALUE = 1\n"

        def payload(content: bytes) -> dict[str, str]:
            return {
                "content": base64.b64encode(content).decode(),
                "sha256": lun_cluster.hashlib.sha256(content).hexdigest(),
            }

        return payload(script), payload(agent)

    def _record_sample(self, node_id: str, country: str, city: str, remark: str) -> None:
        server_number = self.cluster.allocate_server_number(node_id)
        place = lun_cluster.chinese_place({"country_code": country, "city": city})
        name = f"[{place}]vless-xhttp-tls-tcp-{server_number:02d}"
        status = {
            "node_id": node_id, "public_host": "127.0.0.1", "public_port": 20000,
            "internal_port": 20000, "api_version": 1, "remark": remark,
            "location": {"country_code": country, "city": city},
        }
        generic = f"vless://11111111-1111-4111-8111-111111111111@127.0.0.1:443#{name}\n"
        clash = f"""proxies:
- name: {name}
  type: vless
  server: 127.0.0.1
  port: 443
  uuid: 11111111-1111-4111-8111-111111111111
proxy-groups:
- name: select
  type: select
  proxies:
    - {name}
rules:
  - MATCH,select
"""
        singbox = json.dumps({
            "inbounds": [], "outbounds": [{"type": "vless", "tag": name, "server": "127.0.0.1",
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
