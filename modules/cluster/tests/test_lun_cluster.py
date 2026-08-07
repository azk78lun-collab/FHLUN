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
        self.assertEqual(result["version"], "V26.8.8.2")
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
            "result": {"status": "success", "result": {"complete": True, "version": "V26.8.8.2"}}
        }
        with mock.patch.object(lun_cluster, "mutual_request", return_value=response) as request:
            result = lun_cluster.request_cluster_update(self.cluster, payload)
        self.assertTrue(result["complete"])
        self.assertEqual(request.call_args.args[2:5], (20000, "POST", "/v1/action"))
        self.assertEqual(request.call_args.args[5]["action"], "cluster.update-all")

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

    def _add_node(self, node_id: str, country: str) -> None:
        self.cluster.upsert_node({
            "node_id": node_id, "public_host": "127.0.0.1", "public_port": 20000,
            "internal_port": 20000, "api_version": 1,
            "location": {"country_code": country},
        })

    @staticmethod
    def _update_payloads() -> tuple[dict[str, str], dict[str, str]]:
        script = b"#!/usr/bin/env bash\n# V26.8.8.2\nexit 0\n"
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
