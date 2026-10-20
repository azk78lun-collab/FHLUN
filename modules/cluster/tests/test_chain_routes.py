from __future__ import annotations

import base64
import importlib.util
import json
import os
import socket
import socketserver
import ssl
import subprocess
import tempfile
import threading
import time
import unittest
import uuid
from pathlib import Path
from unittest import mock

SPEC = importlib.util.spec_from_file_location("chain_cluster", Path(__file__).resolve().parents[1] / "lun_cluster.py")
mod = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(mod)
PRIVATE = base64.urlsafe_b64encode(bytes.fromhex("77076d0a7318a57d3c16c17251b26645df4c2f87ebc0992ab177fba51db92c2a")).decode().rstrip("=")
PUBLIC = base64.urlsafe_b64encode(bytes.fromhex("8520f0098930a754748b7ddcb43ef75a0dbf3a0d26381af4eba4a98eaa9b4e6a")).decode().rstrip("=")
LEGACY = "11111111-1111-4111-8111-111111111111"


def base_core(port=23456):
    return {"inbounds": [{"tag": "reality-vision", "listen": "::", "port": port, "protocol": "vless",
             "settings": {"decryption": "none", "clients": [{"id": LEGACY, "flow": "xtls-rprx-vision"}]},
             "streamSettings": {"network": "tcp", "security": "reality", "realitySettings": {
                 "target": "example.com:443", "serverNames": ["example.com"], "privateKey": PRIVATE,
                 "shortIds": ["0123456789abcdef"]}}}],
            "outbounds": [{"tag": "direct", "protocol": "freedom", "settings": {"domainStrategy": "UseIPv6"}},
                          {"tag": "warp-out", "protocol": "freedom", "settings": {}}],
            "routing": {"rules": [{"type": "field", "network": "tcp,udp", "outboundTag": "warp-out"}]}}


class ChainTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        script = Path(self.temp.name) / "lun.sh"
        script.write_text("chain_preserve_existing_core_fields(){ :; }\n")
        self.script_environment = mock.patch.dict(os.environ, {"LUN_SCRIPT": str(script)})
        self.script_environment.start()
        self.aid, self.bid = "a" * 32, "b" * 32
        self.clusters = {}
        self.status = {self.aid: {"node_id": self.aid, "public_host": "8.8.8.8", "public_port": 39001,
                     "internal_port": 39001, "location": {"country_code": "JP", "country": "日本", "city": "大阪"}},
                      self.bid: {"node_id": self.bid, "public_host": "1.1.1.1", "public_port": 39002,
                     "internal_port": 39002, "location": {"country_code": "JP", "country": "日本", "city": "东京"}}}
        for number, node_id in enumerate((self.aid, self.bid), 1):
            root = Path(self.temp.name) / node_id
            root.mkdir()
            (root / "uuid").write_text(LEGACY)
            cluster = mod.Cluster(root)
            cluster.save_config({"mode": "federation", "role": "federation", "enabled": True,
                                 "node_id": node_id, "server_number": number,
                                 "public_host": self.status[node_id]["public_host"],
                                 "internal_port": 39000 + number, "public_port": 39000 + number})
            for status in self.status.values():
                cluster.upsert_node(status, role="federation")
                cluster.db.connection.execute("INSERT INTO federation_keys(node_id,root_certificate,created_at,updated_at) VALUES(?,?,1,1)",
                                              (status["node_id"], "fixture"))
            cluster.db.connection.commit()
            (root / "xr.json").write_text(json.dumps(base_core()))
            agent = root / "modules/multiuser/lun_agent.py"
            agent.parent.mkdir(parents=True)
            agent.write_text("# capability: lun-chain-entry-\n")
            self.clusters[node_id] = cluster
            self.sources(root)
        self.a, self.b = self.clusters[self.aid], self.clusters[self.bid]
        self.calls = []
        self.fail_entry = False
        self.runtime = []
        for cluster in self.clusters.values():
            cluster._run = lambda command, _cluster=cluster, **kw: self.run_local(_cluster, command)
        self.transport = mock.patch.object(mod, "send_action", side_effect=self.send)
        self.transport.start()

    def tearDown(self):
        self.script_environment.stop()
        self.transport.stop()
        for cluster in self.clusters.values():
            cluster.close()
        self.temp.cleanup()

    @staticmethod
    def sources(root):
        (root / "jhsub.txt").write_text("vless://" + LEGACY + "@8.8.8.8:23456#ordinary\n")
        (root / "sbox.json").write_text(json.dumps({"outbounds": [
            {"type": "vless", "tag": "ordinary", "uuid": LEGACY},
            {"type": "selector", "tag": "manual", "outbounds": ["ordinary"], "default": "ordinary"},
            {"type": "urltest", "tag": "auto", "outbounds": ["ordinary"]}]}))
        (root / "clmi.yaml").write_text("proxies:\n- name: ordinary\n  type: vless\n  uuid: " + LEGACY +
             "\nproxy-groups:\n- name: manual\n  type: select\n  proxies:\n    - ordinary\n"
             "- name: auto\n  type: url-test\n  proxies:\n    - ordinary\nrules:\n  - MATCH,manual\n")

    def run_local(self, cluster, command):
        self.runtime.append((cluster, command[-1]))
        if command[-1] in {"chain-runtime-apply", "chain-runtime-restore"}:
            mod.ChainRoutes(cluster).inject_core()
            self.sources(cluster.root)
            mod.ChainRoutes(cluster).subscriptions()
            if self.fail_entry and cluster is self.a and command[-1] == "chain-runtime-apply":
                return subprocess.CompletedProcess(command, 1, "", "fixture failure")
        return subprocess.CompletedProcess(command, 0, "", "")

    def send(self, source, node_id, action, payload, **kwargs):
        self.calls.append((node_id, action, payload))
        return mod.execute_action(self.clusters[node_id], {"action": action, "payload": payload,
                                  "request_id": uuid.uuid4().hex}, source.load_config()["node_id"])

    def create(self):
        with mock.patch.object(mod.ChainRoutes, "public_key", return_value=PUBLIC):
            return mod.chain_create(self.a, self.aid, self.bid)

    def test_x25519_derivation_never_places_private_key_in_arguments(self):
        completed = subprocess.CompletedProcess([], 0, bytes.fromhex("302a300506032b656e032100") + base64.urlsafe_b64decode(PUBLIC + "="), b"")
        with mock.patch.object(mod.subprocess, "run", return_value=completed) as call:
            self.assertEqual(mod.ChainRoutes.public_key(PRIVATE), PUBLIC)
            self.assertNotIn(PRIVATE, str(call.call_args.args[0]))
            self.assertEqual(len(call.call_args.kwargs["input"]), 48)

    def test_two_hop_create_isolated_routes_and_single_transit_identity(self):
        result = self.create()
        cid = result["chain_id"]
        a, b = (json.loads(c.root.joinpath("xr.json").read_text()) for c in (self.a, self.b))
        self.assertEqual(len(a["inbounds"]), 2)
        self.assertEqual(a["inbounds"][0], base_core()["inbounds"][0])
        outbound = next(o for o in a["outbounds"] if o["tag"] == "lun-chain-" + cid)
        transit = next(c for c in b["inbounds"][0]["settings"]["clients"] if c.get("email", "").startswith("lun-transit-"))
        self.assertEqual(outbound["settings"]["vnext"][0]["users"][0]["id"], transit["id"])
        self.assertNotEqual(transit["id"], LEGACY)
        self.assertEqual(transit["level"], 1)
        self.assertEqual(b["outbounds"][0], base_core()["outbounds"][0])
        route = next(r for r in a["routing"]["rules"] if r.get("outboundTag") == "lun-chain-" + cid)
        self.assertEqual(route["network"], "tcp")
        self.assertTrue(any(r.get("network") == "udp" and r.get("outboundTag") == "lun-chain-blocked" for r in a["routing"]["rules"]))
        self.assertTrue(any(r.get("user") == [transit["email"]] and r["outboundTag"] == "lun-chain-direct" for r in b["routing"]["rules"]))

    def test_inject_is_idempotent_and_keeps_existing_guard_first(self):
        self.create()
        manager = mod.ChainRoutes(self.a)
        data = manager.core()
        data["outbounds"].append({"tag": "custom-deny", "protocol": "blackhole"})
        guard = {"type": "field", "domain": ["full:blocked.test"], "outboundTag": "custom-deny"}
        data["routing"]["rules"].append(guard)
        first = manager.inject(data)
        self.assertEqual(first, manager.inject(first))
        self.assertEqual(first["routing"]["rules"][0], guard)

    def test_three_subscriptions_use_same_name_no_exit_credentials_or_auto_selection(self):
        result = self.create()
        cid, name = result["chain_id"], result["name"]
        hop_uuid = mod.ChainRoutes(self.b).load()["routes"][cid]["hop_uuid"]
        for filename in mod.SUBSCRIPTION_FILES:
            a = self.a.root.joinpath(filename).read_text(encoding="utf-8")
            b = self.b.root.joinpath(filename).read_text(encoding="utf-8")
            self.assertNotIn(hop_uuid, a + b)
            self.assertNotIn(PRIVATE, a + b)
            self.assertNotIn("chain-tcp", b)
        data = json.loads(self.a.root.joinpath("sbox.json").read_text(encoding="utf-8"))
        manual = next(o for o in data["outbounds"] if o["tag"] == "manual")
        auto = next(o for o in data["outbounds"] if o["tag"] == "auto")
        self.assertIn(name, manual["outbounds"])
        self.assertEqual(manual["default"], "ordinary")
        self.assertNotIn(name, auto["outbounds"])
        with mock.patch.object(mod.ChainRoutes, "public_key", return_value=PUBLIC):
            mod.ChainRoutes(self.a).subscriptions()
        clash = self.a.root.joinpath("clmi.yaml").read_text(encoding="utf-8")
        self.assertEqual(clash.count("- name: " + json.dumps(name, ensure_ascii=False)), 1)
        self.assertIn("  proxies:\n    - ordinary\n    - " + json.dumps(name, ensure_ascii=False), clash)
        self.assertNotIn(name, clash.split("- name: auto", 1)[1])

    def test_entry_failure_and_lost_response_cleanup_both_sides(self):
        self.fail_entry = True
        with self.assertRaises(mod.ClusterError):
            self.create()
        self.assertFalse(mod.ChainRoutes(self.a).load()["routes"])
        self.assertFalse(mod.ChainRoutes(self.b).load()["routes"])
        self.assertEqual(json.loads(self.a.root.joinpath("xr.json").read_text()), base_core())
        self.assertEqual(json.loads(self.b.root.joinpath("xr.json").read_text()), base_core())
        self.assertFalse(list(self.a.root.glob("port_chain_*")))

    def test_committed_entry_with_lost_response_is_removed_from_both_members(self):
        def lost(source, node_id, action, payload, **kwargs):
            response = self.send(source, node_id, action, payload, **kwargs)
            if node_id == self.aid and action == "chain.entry.create":
                raise mod.FederationTransportError("response lost after successful commit")
            return response
        with mock.patch.object(mod, "send_action", side_effect=lost), mock.patch.object(mod.ChainRoutes, "public_key", return_value=PUBLIC):
            with self.assertRaises(mod.ClusterError):
                mod.chain_create(self.b, self.aid, self.bid)
        self.assertFalse(mod.ChainRoutes(self.a).load()["routes"])
        self.assertFalse(mod.ChainRoutes(self.b).load()["routes"])

    def test_removal_and_recreation_do_not_reuse_transit_credentials(self):
        created = self.create()
        first = mod.ChainRoutes(self.b).load()["routes"][created["chain_id"]]["hop_uuid"]
        for target in (self.a, self.b):
            manager = mod.ChainRoutes(target)
            manager.action("chain.remove", {"chain_id": created["chain_id"]}, "local")
            self.assertEqual(manager.core(), base_core())
        second = self.create()
        self.assertNotEqual(first, mod.ChainRoutes(self.b).load()["routes"][second["chain_id"]]["hop_uuid"])

    def test_failed_rollback_keeps_private_snapshot_and_never_claims_success(self):
        manager = mod.ChainRoutes(self.a)
        self.a._run = lambda command, **kw: subprocess.CompletedProcess(command, 0 if command[-1] == "chain-runtime-status" else 1, "", "")
        with self.assertRaisesRegex(mod.ClusterError, "快照"):
            manager.apply({"version": 1, "routes": {}})
        self.assertTrue(list(self.a.root.glob(".chain-transaction-*")))

    def test_stopped_core_refuses_mutation_without_starting_it(self):
        self.a._run = mock.Mock(return_value=subprocess.CompletedProcess([], 1, "", ""))
        with self.assertRaisesRegex(mod.ClusterError, "尚未运行"):
            mod.ChainRoutes(self.a).apply({"version": 1, "routes": {}})
        self.assertFalse((self.a.root / "chain_routes.json").exists())
        self.assertEqual(self.a._run.call_count, 1)

    def test_backup_failure_leaves_state_unchanged_and_removes_partial_snapshot(self):
        manager = mod.ChainRoutes(self.a)
        original = (self.a.root / "xr.json").read_bytes()
        with mock.patch.object(mod.shutil, "copy2", side_effect=OSError("backup unavailable")):
            with self.assertRaises(OSError):
                manager.apply({"version": 1, "routes": {}})
        self.assertFalse(manager.path.exists())
        self.assertEqual((self.a.root / "xr.json").read_bytes(), original)
        self.assertFalse(list(self.a.root.glob(".chain-transaction-*")))

    def test_restore_timeout_reports_retained_snapshot(self):
        def fail(command, **kwargs):
            if command[-1] == "chain-runtime-restore":
                raise subprocess.TimeoutExpired(command, 300)
            return subprocess.CompletedProcess(command, 0 if command[-1] == "chain-runtime-status" else 1, "", "")
        self.a._run = fail
        with self.assertRaisesRegex(mod.ClusterError, "保留快照"):
            mod.ChainRoutes(self.a).apply({"version": 1, "routes": {}})
        self.assertTrue(list(self.a.root.glob(".chain-transaction-*")))

    def test_retired_identity_does_not_revive_saved_routes(self):
        self.create()
        config = self.a.load_config()
        config["node_id"] = "d" * 32
        self.a.save_config(config)
        manager = mod.ChainRoutes(self.a)
        self.assertFalse(manager.rows()[0]["active"])
        self.assertEqual(len(manager.inject(manager.core())["inbounds"]), 1)

    def test_pending_metadata_is_not_lost_during_reconciliation(self):
        self.create()
        manager = mod.ChainRoutes(self.a)
        manager.queue_peer(self.bid)
        with mock.patch.object(manager, "apply", side_effect=lambda value: manager.queue_peer(self.bid)):
            manager.reconcile_pending()
        self.assertTrue(self.a.db.setting("chain.pending"))

    def test_port_mapping_pool_conflicts_and_ipv6_native_port(self):
        manager = mod.ChainRoutes(self.a)
        self.a.root.joinpath("vps_mode").write_text("nat")
        self.a.root.joinpath("port_map").write_text("40001-23456 40002-23457")
        self.assertEqual(manager.public_port(23456), 40001)
        self.assertEqual(manager.choose_port(), 23457)
        with self.assertRaises(mod.ClusterError):
            manager.choose_port(23456)
        with self.assertRaises(mod.ClusterError):
            manager.public_port(55555)
        config = self.a.load_config()
        config.update(public_host="2001:4860:4860::8888", public_hosts=["2001:4860:4860::8888"])
        self.a.save_config(config)
        self.assertEqual(manager.endpoint(23456), ("2001:4860:4860::8888", 23456))

    def test_busy_port_and_same_node_rejected_without_remote_mutations(self):
        with socket.socket() as listener:
            listener.bind(("127.0.0.1", 0))
            with self.assertRaises(mod.ClusterError):
                mod.ChainRoutes(self.a).choose_port(listener.getsockname()[1])
        with self.assertRaises(mod.ClusterError):
            mod.chain_plan(self.a, self.aid, self.aid)
        self.assertEqual(self.calls, [])

    def test_preflight_missing_reality_requires_two_entry_ports_without_mutation(self):
        self.a.root.joinpath("xr.json").write_text(json.dumps({"inbounds": []}))
        self.a.root.joinpath("vps_mode").write_text("nat")
        self.a.root.joinpath("port_map").write_text("45001-25001")
        before = self.a.root.joinpath("xr.json").read_bytes()
        with self.assertRaises(mod.ClusterError):
            mod.chain_plan(self.a, self.aid, self.bid)
        self.assertEqual(self.a.root.joinpath("xr.json").read_bytes(), before)
        self.assertFalse(any(action == "chain.enable-reality" for _, action, _ in self.calls))
        self.a.root.joinpath("port_map").write_text("45001-25001 45002-25002")
        plan = mod.chain_plan(self.a, self.aid, self.bid, 25001)
        self.assertTrue(plan["entry"]["needs_reality"])
        self.assertEqual(plan["entry"]["reality_port"], 25002)
        self.assertEqual(plan["public_port"], 45001)

    def test_normal_pool_supports_lun_plus_ranges_and_exhaustion(self):
        self.a.root.joinpath("xr.json").unlink()
        self.a.root.joinpath("port_pool").write_text("25001+25002")
        result = mod.ChainRoutes(self.a).preflight("entry", 25001)
        self.assertEqual((result["chain_port"], result["reality_port"]), (25001, 25002))
        self.a.root.joinpath("port_pool").write_text("25001")
        with self.assertRaises(mod.ClusterError):
            mod.ChainRoutes(self.a).preflight("entry", 25001)
        self.a.root.joinpath("vps_mode").write_text("nat")
        with self.assertRaisesRegex(mod.ClusterError, "没有可用映射"):
            mod.ChainRoutes(self.a).choose_port()

    def test_auto_enable_both_reality_keeps_ports_uuid_and_existing_sni(self):
        for cluster in (self.a, self.b):
            cluster.root.joinpath("xr.json").write_text(json.dumps({"inbounds": [], "outbounds": []}))
            cluster.root.joinpath("port_vx").write_text("23455")
            cluster.root.joinpath("port_vw").write_text("23454")
            cluster.root.joinpath("ym_vl_re").write_text("existing.example.com")
            cluster.root.joinpath("vlvm").write_text("Vless")
            cluster.root.joinpath("sbargoym.log").write_text("tunnel.example.com")
            cluster.root.joinpath("sbargotoken.log").write_text("fixture-local-token")
        original = mod._execute_action_locked
        prepared = []
        def apply(cluster, action, payload, request, peer):
            if action != "protocol.apply":
                return original(cluster, action, payload, request, peer)
            self.assertEqual(payload["vxpt"], "23455")
            self.assertEqual(payload["uuid"], LEGACY)
            self.assertEqual(payload["reym"], "existing.example.com")
            self.assertEqual(payload["argo"], "vwpt")
            self.assertEqual(payload["agn"], "tunnel.example.com")
            self.assertEqual(payload["agk"], "fixture-local-token")
            cluster.root.joinpath("xr.json").write_text(json.dumps(base_core(int(payload["vlpt"]))))
            cluster.root.joinpath("port_vl_re").write_text(payload["vlpt"])
            prepared.append(cluster)
            return {"returncode": 0}
        with mock.patch.object(mod, "_execute_action_locked", side_effect=apply):
            result = self.create()
        self.assertEqual(prepared, [self.b, self.a])
        self.assertTrue(result["chain_id"])
        self.assertEqual(self.a.root.joinpath("uuid").read_text(), LEGACY)
        self.assertEqual(self.b.root.joinpath("port_vx").read_text(), "23455")
        self.assertNotEqual(result["port"], int(self.a.root.joinpath("port_vl_re").read_text()))

    def test_exit_shortage_is_detected_before_preparing_entry(self):
        self.b.root.joinpath("xr.json").write_text(json.dumps({"inbounds": []}))
        self.b.root.joinpath("port_pool").write_text("39002")  # federation listener owns this port
        with self.assertRaises(mod.ClusterError):
            self.create()
        self.assertFalse(any(action in {"chain.enable-reality", "chain.exit.create"}
                             for _, action, _ in self.calls))

    def test_corrupt_state_and_missing_reality_do_not_silently_drop_chain(self):
        manager = mod.ChainRoutes(self.a)
        manager.path.write_text("{")
        with self.assertRaises(mod.ClusterError):
            manager.inject(manager.core())
        manager.path.unlink()
        self.create()
        data = manager.core()
        data["inbounds"] = [i for i in data["inbounds"] if i["tag"] != "reality-vision"]
        with self.assertRaises(mod.ClusterError):
            manager.inject(data)

    def test_credentials_only_disclosed_to_corresponding_entry(self):
        result = self.create()
        manager = mod.ChainRoutes(self.b)
        with self.assertRaises(mod.ClusterError):
            manager.action("chain.describe", {"chain_id": result["chain_id"]}, "c" * 32)
        self.assertNotIn("hop_uuid", json.dumps(manager.rows()))
        self.assertNotIn(PRIVATE, json.dumps(manager.rows()))
        with self.assertRaises(mod.ClusterError):
            manager.action("chain.remove", {"chain_id": "../../danger"}, "local")
        with self.assertRaises(mod.ClusterError):
            manager.action("chain.list", {"shell": "evil"}, "local")

    def test_member_revocation_closes_chain_and_suppresses_cached_subscriptions(self):
        result = self.create()
        manager = mod.ChainRoutes(self.a)
        self.a.db.connection.execute("UPDATE federation_keys SET revoked_at=1 WHERE node_id=?", (self.bid,))
        self.a.db.connection.commit()
        self.assertFalse(manager.name_allowed(self.a, result["name"]))
        updated = manager.inject(manager.core())
        self.assertEqual(len(updated["inbounds"]), 1)
        self.assertFalse(any(o["tag"].startswith("lun-chain-") for o in updated["outbounds"]))
        manager.queue_peer(self.bid)
        manager.reconcile_pending()
        self.assertFalse(manager.load()["routes"][result["chain_id"]]["active"])
        self.assertNotIn("chain-tcp", self.a.root.joinpath("jhsub.txt").read_text())

    def test_public_ip_event_retargets_only_the_registered_exit(self):
        result = self.create()
        status = dict(self.status[self.bid], public_host="9.9.9.9")
        self.a.upsert_node(status, role="federation")
        updated = mod.ChainRoutes(self.a).inject(mod.ChainRoutes(self.a).core())
        outbound = next(o for o in updated["outbounds"] if o["tag"] == "lun-chain-" + result["chain_id"])
        self.assertEqual(outbound["settings"]["vnext"][0]["address"], "9.9.9.9")
        self.assertEqual(outbound["settings"]["vnext"][0]["port"], 23456)

    @unittest.skipUnless(os.environ.get("LUN_TEST_XRAY"), "optional real Xray binary not supplied")
    def test_real_core_accepts_both_generated_configurations(self):
        self.create()
        for cluster in (self.a, self.b):
            checked = subprocess.run([os.environ["LUN_TEST_XRAY"], "run", "-test", "-c", str(cluster.root / "xr.json")],
                                     capture_output=True, text=True, timeout=20)
            self.assertEqual(checked.returncode, 0, checked.stdout + checked.stderr)

    @unittest.skipUnless(os.environ.get("LUN_TEST_XRAY") and os.environ.get("LUN_TEST_CHAIN_LIVE") == "1",
                         "optional live local-chain test not requested")
    def test_real_three_process_chain_fails_closed_and_keeps_ordinary_entry(self):
        binary = os.environ["LUN_TEST_XRAY"]
        def free_port():
            with socket.socket() as connection:
                connection.bind(("127.0.0.1", 0))
                return connection.getsockname()[1]
        key, cert = self.a.root / "tls.key", self.a.root / "tls.crt"
        subprocess.run(["openssl", "req", "-x509", "-newkey", "rsa:2048", "-nodes", "-days", "1",
                        "-subj", "/CN=example.com", "-keyout", str(key), "-out", str(cert)],
                       check=True, capture_output=True, timeout=30)
        context = ssl.SSLContext(ssl.PROTOCOL_TLS_SERVER)
        context.minimum_version = ssl.TLSVersion.TLSv1_3
        context.set_alpn_protocols(["h2", "http/1.1"])
        context.load_cert_chain(str(cert), str(key))
        class TLSOrigin(socketserver.BaseRequestHandler):
            def handle(self):
                try:
                    self.request.settimeout(8)
                    with context.wrap_socket(self.request, server_side=True) as wrapped:
                        wrapped.recv(4096)
                except (OSError, ssl.SSLError):
                    pass
        class OriginServer(socketserver.ThreadingTCPServer):
            daemon_threads = True
        origin = OriginServer(("127.0.0.1", 0), TLSOrigin)
        worker = threading.Thread(target=origin.serve_forever, daemon=True)
        worker.start()
        children, handles = [], []
        def stop(process):
            if process.poll() is None:
                process.terminate()
                try:
                    process.wait(5)
                except subprocess.TimeoutExpired:
                    process.kill()
                    process.wait(5)
        def start(path, port):
            log = open(path.with_suffix(".runtime.log"), "wb")
            handles.append(log)
            process = subprocess.Popen([binary, "run", "-c", str(path)], stdout=log, stderr=log)
            children.append(process)
            deadline = time.monotonic() + 10
            while time.monotonic() < deadline and process.poll() is None:
                try:
                    with socket.create_connection(("127.0.0.1", port), timeout=0.2):
                        return process
                except OSError:
                    time.sleep(0.05)
            self.fail("Xray test process did not listen: " + str(path))
        def receive_exact(connection, size):
            output = b""
            while len(output) < size:
                chunk = connection.recv(size - len(output))
                if not chunk:
                    raise OSError("connection closed")
                output += chunk
            return output
        def request(port):
            with socket.create_connection(("127.0.0.1", port), timeout=8) as raw:
                raw.sendall(b"\x05\x01\x00")
                if receive_exact(raw, 2) != b"\x05\x00":
                    raise OSError("SOCKS authentication failed")
                target = b"example.com"
                raw.sendall(b"\x05\x01\x00\x03" + bytes([len(target)]) + target + (443).to_bytes(2, "big"))
                response = receive_exact(raw, 4)
                if response[1] != 0:
                    raise OSError("SOCKS connect rejected")
                receive_exact(raw, (4 if response[3] == 1 else 16) + 2)
                with ssl.create_default_context().wrap_socket(raw, server_hostname="example.com") as secure:
                    secure.sendall(b"GET / HTTP/1.1\r\nHost: example.com\r\nConnection: close\r\n\r\n")
                    return secure.recv(4096).split(b"\r\n")[0]
        try:
            pa, pb, pc = free_port(), free_port(), free_port()
            for cluster, port in ((self.a, pa), (self.b, pb)):
                data = base_core(port)
                data["inbounds"][0]["streamSettings"]["realitySettings"]["target"] = f"127.0.0.1:{origin.server_address[1]}"
                cluster.root.joinpath("xr.json").write_text(json.dumps(data), encoding="utf-8")
            result = self.create()
            for cluster in (self.a, self.b):
                data = json.loads(cluster.root.joinpath("xr.json").read_text())
                data["log"] = {"loglevel": "warning", "access": str(cluster.root / "access.log")}
                for inbound in data["inbounds"]:
                    inbound["listen"] = "127.0.0.1"
                for outbound in data["outbounds"]:
                    if outbound["protocol"] == "vless":
                        # Local integration only: the two test VPS instances share this computer.
                        outbound["settings"]["vnext"][0]["address"] = "127.0.0.1"
                cluster.root.joinpath("xr.json").write_text(json.dumps(data), encoding="utf-8")
            b_process = start(self.b.root / "xr.json", pb)
            start(self.a.root / "xr.json", result["port"])
            client = {"inbounds": [{"tag": "local", "listen": "127.0.0.1", "port": pc,
                       "protocol": "socks", "settings": {"auth": "noauth", "udp": False}}],
                      "outbounds": [{"protocol": "vless", "settings": {"vnext": [{"address": "127.0.0.1",
                       "port": result["port"], "users": [{"id": LEGACY, "encryption": "none", "flow": "xtls-rprx-vision"}]}]},
                       "streamSettings": {"network": "tcp", "security": "reality", "realitySettings": {
                           "serverName": "example.com", "publicKey": PUBLIC, "shortId": "0123456789abcdef", "fingerprint": "chrome"}}}]}
            path = self.a.root / "client.json"
            path.write_text(json.dumps(client), encoding="utf-8")
            c_process = start(path, pc)
            self.assertIn(b"200", request(pc))
            self.assertIn("lun-transit-", self.b.root.joinpath("access.log").read_text(encoding="utf-8"))
            stop(b_process)
            with self.assertRaises((OSError, ssl.SSLError)):
                request(pc)
            stop(c_process)
            client["outbounds"][0]["settings"]["vnext"][0]["port"] = pa
            path.write_text(json.dumps(client), encoding="utf-8")
            start(path, pc)
            self.assertIn(b"200", request(pc))
        finally:
            for process in reversed(children):
                stop(process)
            for handle in handles:
                handle.close()
            origin.shutdown()
            origin.server_close()


if __name__ == "__main__":
    unittest.main()
