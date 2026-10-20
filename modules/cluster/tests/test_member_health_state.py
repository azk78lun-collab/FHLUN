from __future__ import annotations

import base64
import hashlib
import http.client
import importlib.util
import json
import tempfile
import unittest
from pathlib import Path
from unittest import mock

SPEC = importlib.util.spec_from_file_location("member_health", Path(__file__).resolve().parents[1] / "lun_cluster.py")
m = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(m)


class MemberHealthTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.c = m.Cluster(Path(self.tmp.name) / "lun")
        self.local, self.peer = "a" * 32, "b" * 32
        self.now = m.utc_now() + 10
        self.c.save_config({"mode": "federation", "role": "federation", "enabled": True,
                            "node_id": self.local, "public_host": "127.0.0.1", "public_port": 21000})
        for ident, port in ((self.local, 21000), (self.peer, 21001)):
            self.c.upsert_node({"node_id": ident, "public_host": "127.0.0.1", "public_port": port,
                                "internal_port": port, "location": {}}, role="federation")
            self.c.db.connection.execute(
                "INSERT INTO federation_keys(node_id,root_certificate,created_at,updated_at) VALUES(?,?,1,1)",
                (ident, "fixture"))
        self.c.db.connection.commit()

    def tearDown(self):
        self.c.close()
        self.tmp.cleanup()

    def failures(self):
        return self.c.db.connection.execute("SELECT COUNT(*) FROM federation_failures WHERE candidate_id=?", (self.peer,)).fetchone()[0]

    def suspect(self):
        self.c.record_transport_failure(self.peer, when=self.now - 5)
        self.assertEqual(self.c.node(self.peer)["state"], "suspect")

    def test_direct_mtls_success_recovers_without_events_or_heartbeat(self):
        self.suspect()
        before = self.c.db.connection.execute("SELECT COUNT(*) FROM federation_events").fetchone()[0]
        with mock.patch.object(m, "mutual_request", return_value={"ok": True}), \
                mock.patch.object(m, "utc_now", return_value=self.now):
            m.member_request(self.c, self.peer, "POST", "/v1/federation/snapshot", {})
        self.assertEqual(self.c.node(self.peer)["state"], "online")
        self.assertEqual(self.failures(), 0)
        self.assertEqual(self.c.db.connection.execute("SELECT COUNT(*) FROM federation_events").fetchone()[0], before)

    def test_identity_or_api_rejection_does_not_claim_recovery(self):
        for error in (m.ClusterError("identity mismatch"), m.ClusterError("permission denied")):
            self.suspect()
            with mock.patch.object(m, "mutual_request", side_effect=error):
                with self.assertRaises(m.ClusterError):
                    m.member_request(self.c, self.peer, "POST", "/v1/action", {})
            self.assertEqual(self.c.node(self.peer)["state"], "suspect")

    def test_status_identity_mismatch_is_not_a_live_success(self):
        self.suspect()
        with mock.patch.object(m, "mutual_request", return_value={"status": {"node_id": self.local}}):
            with self.assertRaisesRegex(m.ClusterError, "identity mismatch"):
                m.member_request(self.c, self.peer, "GET", "/v1/status")
        self.assertEqual(self.c.node(self.peer)["state"], "suspect")

    def test_ipv6_fallback_success_clears_previous_failures(self):
        self.suspect()
        node = dict(self.c.node(self.peer), endpoint_hosts='["2001:4860:4860::8888"]')
        with mock.patch.object(m, "mutual_request", side_effect=[m.FederationTransportError("IPv4 down"), {"ok": True}]) as req:
            m.member_request(self.c, node, "POST", "/v1/federation/events", {})
        self.assertEqual(req.call_count, 2)
        self.assertEqual(self.c.node(self.peer)["state"], "online")

    def push(self, response=None, error=None):
        with mock.patch.object(self.c, "record_local_snapshot"), \
                mock.patch.object(self.c, "federation_snapshot", return_value={"status": {"node_id": self.local}}), \
                mock.patch.object(m, "utc_now", return_value=self.now), \
                mock.patch.object(m, "mutual_request", return_value=response or {"ok": True}, side_effect=error):
            return m.push_snapshot(self.c)

    def test_successful_snapshot_push_clears_suspect(self):
        self.suspect()
        self.assertEqual(self.push()["peers"][self.peer], "ok")
        self.assertEqual(self.c.node(self.peer)["state"], "online")
        self.assertEqual(self.failures(), 0)

    def test_snapshot_business_error_is_not_marked_offline(self):
        for message in ("database busy", "federation transport failed: [Errno 111] Connection refused"):
            result = self.push(error=m.ClusterError(message))
            self.assertIn("failed", result["peers"][self.peer])
            self.assertEqual(self.c.node(self.peer)["state"], "online")
            self.assertEqual(self.failures(), 0)

    def test_snapshot_transport_failure_is_still_reported(self):
        self.push(error=m.FederationTransportError("connection refused"))
        self.assertEqual(self.c.node(self.peer)["state"], "suspect")
        self.assertEqual(self.failures(), 1)

    def test_older_inflight_failure_cannot_overwrite_new_success(self):
        self.c.record_transport_success(self.peer, when=self.now + 1)
        result = self.c.record_transport_failure(self.peer, when=self.now + 5, started_at=self.now)
        self.assertTrue(result["ignored"])
        self.assertEqual(self.c.node(self.peer)["state"], "online")
        self.assertEqual(self.failures(), 0)

    def test_same_second_success_is_protected_from_delayed_failure(self):
        self.c.record_transport_success(self.peer, when=self.now)
        result = self.c.record_transport_failure(self.peer, when=self.now + 2, started_at=self.now)
        self.assertTrue(result["ignored"])
        self.assertEqual(self.c.node(self.peer)["state"], "online")

    def test_push_restart_race_preserves_fresher_health(self):
        def interrupted(*args, **kwargs):
            self.c.record_transport_success(self.peer, when=self.now + 1)
            raise m.FederationTransportError("old stream closed during restart")
        result = self.push(error=interrupted)
        self.assertIn("failed", result["peers"][self.peer])
        self.assertEqual(self.c.node(self.peer)["state"], "online")
        self.assertEqual(self.failures(), 0)

    def test_revoked_node_is_never_revived_by_stale_response(self):
        self.c.db.connection.execute("UPDATE nodes SET state='revoked' WHERE id=?", (self.peer,))
        self.c.db.connection.commit()
        self.c.record_transport_success(self.peer)
        self.c.record_transport_failure(self.peer, started_at=self.now)
        self.assertEqual(self.c.node(self.peer)["state"], "revoked")

    def update(self, effect):
        script = b'#!/usr/bin/env bash\necho "V26.10.20.2"\n'
        agent = b'#!/usr/bin/env python3\nprint("fixture")\n'
        def payload(content):
            return {"content": base64.b64encode(content).decode(), "sha256": hashlib.sha256(content).hexdigest()}
        with mock.patch.object(m, "send_action", side_effect=effect), \
                mock.patch.object(m, "utc_now", return_value=self.now):
            return m.distribute_cluster_update(self.c, {"script": payload(script), "agent": payload(agent)})

    def test_update_validation_failure_does_not_mark_server_offline(self):
        result = self.update(m.ClusterError("script SHA-256 rejected"))
        self.assertFalse(result["complete"])
        self.assertEqual(self.c.node(self.peer)["state"], "online")
        self.assertEqual(self.failures(), 0)

    def test_update_transport_failure_is_suspect_not_unreachable(self):
        result = self.update(m.FederationTransportError("connect timed out"))
        self.assertFalse(result["complete"])
        self.assertEqual(self.c.node(self.peer)["state"], "suspect")
        self.assertEqual(self.failures(), 1)

    def test_delayed_success_does_not_regress_success_timestamp(self):
        self.c.record_transport_success(self.peer, when=self.now + 5)
        self.c.record_transport_success(self.peer, when=self.now)
        self.assertEqual(self.c.node(self.peer)["last_success"], self.now + 5)

    def test_status_reports_loaded_cluster_module_version(self):
        self.assertEqual(self.c.local_status()["cluster_version"], m.VERSION)

    def test_current_local_listener_can_be_reused_without_restart(self):
        with mock.patch.object(m, "mutual_request", return_value={"status": {
                "node_id": self.local, "cluster_source_sha256": m.CLUSTER_SOURCE_SHA256}}) as request:
            self.assertTrue(m.local_service_current(self.c))
        self.assertEqual(request.call_args.kwargs['expected_node_id'], self.local)

    def test_stale_or_wrong_local_listener_is_not_reused(self):
        for result in ({"status": {"node_id": self.local, "cluster_source_sha256": "old"}},
                       {"status": {"node_id": self.peer, "cluster_source_sha256": m.CLUSTER_SOURCE_SHA256}}):
            with mock.patch.object(m, "mutual_request", return_value=result):
                self.assertFalse(m.local_service_current(self.c))

    def test_identical_agent_push_does_not_restart_or_create_backup(self):
        target = self.c.module / "fixture_agent.py"
        content = b'#!/usr/bin/env python3\nprint("same agent")\n'
        target.write_bytes(content)
        payload = {"content": base64.b64encode(content).decode(), "sha256": hashlib.sha256(content).hexdigest()}
        with mock.patch.object(m, "__file__", str(target)):
            result = m.install_agent_payload(payload)
        self.assertTrue(result["unchanged"])
        self.assertFalse(result["restart_required"])
        self.assertFalse(target.with_name(target.name + ".cluster-backup").exists())

    def test_identical_script_push_is_a_noop(self):
        target = self.c.root / "fixture_lun.sh"
        content = b'#!/usr/bin/env bash\necho same\n'
        target.write_bytes(content)
        payload = {"content": base64.b64encode(content).decode(), "sha256": hashlib.sha256(content).hexdigest()}
        result = m.install_script_payload(self.c, target, payload)
        self.assertTrue(result["unchanged"])
        self.assertFalse(target.with_name(target.name + ".cluster-backup").exists())

    def test_update_waits_for_loaded_module_and_restart_listener(self):
        with mock.patch.object(m, "probe_federation_member", side_effect=[
                {"cluster_version": "0.3.0"}, m.FederationTransportError("restarting"),
                {"cluster_version": "0.3.1"}]) as probe, mock.patch.object(m.time, "sleep") as sleep:
            result = m.wait_for_member_update(self.c, self.peer, "0.3.1")
        self.assertEqual(result["cluster_version"], "0.3.1")
        self.assertEqual(probe.call_count, 3)
        self.assertEqual(sleep.call_count, 2)

    def test_update_restart_wait_is_bounded_and_identity_errors_are_not_retried(self):
        with mock.patch.object(m, "probe_federation_member", side_effect=m.FederationTransportError("down")) as probe, \
                mock.patch.object(m.time, "sleep"):
            with self.assertRaises(m.FederationTransportError):
                m.wait_for_member_update(self.c, self.peer, "0.3.1")
        self.assertEqual(probe.call_count, 6)
        with mock.patch.object(m, "probe_federation_member", side_effect=m.ClusterError("identity mismatch")) as probe:
            with self.assertRaisesRegex(m.ClusterError, "identity mismatch"):
                m.wait_for_member_update(self.c, self.peer, "0.3.1")
        self.assertEqual(probe.call_count, 1)

    def test_update_wait_verifies_loaded_source_even_with_same_version(self):
        with mock.patch.object(m, "probe_federation_member", side_effect=[
                {"cluster_version": m.VERSION, "cluster_source_sha256": "old"},
                {"cluster_version": m.VERSION, "cluster_source_sha256": "new"}]) as probe, \
                mock.patch.object(m.time, "sleep"):
            status = m.wait_for_member_update(self.c, self.peer, m.VERSION, "new")
        self.assertEqual(probe.call_count, 2)
        self.assertEqual(status["cluster_source_sha256"], "new")

    def test_truncated_http_response_during_restart_is_transport_failure(self):
        der = b"test peer certificate"
        self.c.db.connection.execute("UPDATE federation_keys SET identity_fingerprint=? WHERE node_id=?",
                                     (hashlib.sha256(der).hexdigest(), self.peer))
        self.c.db.connection.commit()
        connection = mock.Mock()
        connection.sock.getpeercert.return_value = der
        connection.getresponse.return_value.read.side_effect = http.client.IncompleteRead(b"partial", 100)
        with mock.patch.object(self.c, "federation_trust_bundle", return_value=Path("fixture")), \
                mock.patch.object(m, "federation_client_context"), \
                mock.patch.object(m.http.client, "HTTPSConnection", return_value=connection):
            with self.assertRaises(m.FederationTransportError):
                m.mutual_request(self.c, "127.0.0.1", 21001, "POST", "/v1/action", {}, expected_node_id=self.peer)
        connection.close.assert_called_once()


if __name__ == "__main__":
    unittest.main()
