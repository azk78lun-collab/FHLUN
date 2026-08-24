#!/usr/bin/env python3
import importlib.util
import json
import os
import re
import shutil
import subprocess
import tempfile
import threading
import unittest
import urllib.error
import urllib.request
from pathlib import Path
from unittest import mock

ROOT = Path(__file__).resolve().parents[1]
SPEC = importlib.util.spec_from_file_location("lun_cdn_optimizer", ROOT / "lun_cdn_optimizer.py")
MOD = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(MOD)


class FakeResponse:
    def __init__(self, payload): self.payload = payload
    def __enter__(self): return self
    def __exit__(self, *_): return False
    def read(self, _limit): return self.payload


class OptimizerTests(unittest.TestCase):
    def test_version_and_page_expose_two_independent_boards(self):
        self.assertEqual(MOD.VERSION, "2.0.2")
        for marker in ('id="clientRows"', 'id="vpsRows"', 'id="preview"', 'id="manual"', '一键双向优选'):
            self.assertIn(marker, MOD.PAGE)
        self.assertIn("不做隐藏加权", MOD.PAGE)
        self.assertIn("state.client.filter", MOD.PAGE)
        self.assertIn('class="keep-ip"', MOD.PAGE)
        self.assertIn("页面连接 IP", MOD.PAGE)
        self.assertIn("client_ip:state.clientIp", MOD.PAGE)
        self.assertNotIn("speed.cloudflare.com/meta", MOD.PAGE)
        self.assertNotIn("无法识别客户端网络", MOD.PAGE)

    def test_embedded_javascript_syntax(self):
        node = shutil.which("node")
        if not node:
            self.skipTest("node is not installed")
        script = re.search(r"<script>(.*)</script>", MOD.PAGE, re.S).group(1)
        with tempfile.NamedTemporaryFile("w", suffix=".js", encoding="utf-8", delete=False) as handle:
            handle.write(script)
            path = handle.name
        try:
            result = subprocess.run([node, "--check", path], capture_output=True, text=True)
            self.assertEqual(result.returncode, 0, result.stderr)
        finally:
            Path(path).unlink(missing_ok=True)

    def test_bestcf_endpoint_ipv6_cidr_and_range_parsing(self):
        text = """1.1.1.1:2083#CMCC-IPv4_CMLiu
[2606:4700:4700::1111]:443#CF-IPv6_IPDB
8.8.8.0/30#CIDR
9.9.9.1-9.9.9.3#Range
10.0.0.1#private
broken
"""
        values = MOD._parse_candidate_lines(text, limit=8, seed=7)
        by_ip = {item["ip"]: item for item in values}
        self.assertEqual(by_ip["1.1.1.1"]["port"], 2083)
        self.assertEqual(by_ip["1.1.1.1"]["source"], "CMCC-IPv4_CMLiu")
        self.assertEqual(by_ip["2606:4700:4700::1111"]["ip_type"], "IPv6")
        self.assertNotIn("10.0.0.1", by_ip)

    def test_large_cidr_is_sampled_and_deduplicated(self):
        values = MOD._parse_candidate_lines("108.162.198.0/24\n162.159.38.0/24\n", 64, seed=9)
        self.assertEqual(len(values), 64)
        self.assertEqual(len({item["ip"] for item in values}), 64)

    def test_manual_candidates_accept_lun_space_and_comma_separators(self):
        values = MOD._parse_candidate_lines(
            "172.64.229.200 172.64.229.201，172.64.229.202;172.64.229.203\n172.64.229.204"
        )
        self.assertEqual(
            {item["ip"] for item in values},
            {"172.64.229.200", "172.64.229.201", "172.64.229.202", "172.64.229.203", "172.64.229.204"},
        )

    def test_source_allowlist_latest_good_cache_and_size_limit(self):
        with tempfile.TemporaryDirectory() as tmp:
            payload = b"1.1.1.1#first\n8.8.8.8#second\n"
            with mock.patch.object(MOD.urllib.request, "urlopen", return_value=FakeResponse(payload)):
                text, meta = MOD._fetch_source("bestcf-general", tmp)
            self.assertFalse(meta["cached"])
            with mock.patch.object(MOD.urllib.request, "urlopen", side_effect=urllib.error.URLError("offline")):
                cached, stale = MOD._fetch_source("bestcf-general", tmp)
            self.assertTrue(stale["cached"])
            self.assertEqual(cached, text)
            with self.assertRaises(ValueError): MOD._fetch_source("https://attacker.invalid/list", tmp)
        with tempfile.TemporaryDirectory() as tmp:
            oversized = b"1" * (MOD.MAX_SOURCE_BYTES + 1)
            with mock.patch.object(MOD.urllib.request, "urlopen", return_value=FakeResponse(oversized)):
                with self.assertRaises(ValueError): MOD._fetch_source("bestcf-general", tmp)

    def test_measurements_are_candidate_bound_and_sorted_transparently(self):
        candidates = [
            {"ip": "1.1.1.1", "ip_type": "IPv4", "source": "A", "port": 0},
            {"ip": "8.8.8.8", "ip_type": "IPv4", "source": "B", "port": 0},
        ]
        result = MOD._validate_measurements([
            {"ip": "1.1.1.1", "latency_ms": 20, "speed_mbps": 80},
            {"ip": "8.8.8.8", "latency_ms": 90, "speed_mbps": 160},
            {"ip": "9.9.9.9", "latency_ms": 1, "speed_mbps": 9999},
        ], candidates, "client")
        self.assertEqual([item["ip"] for item in result], ["8.8.8.8", "1.1.1.1"])

    def test_vps_job_has_separate_results(self):
        candidates = [
            {"ip": "1.1.1.1", "ip_type": "IPv4", "source": "A", "port": 0},
            {"ip": "8.8.8.8", "ip_type": "IPv4", "source": "B", "port": 0},
        ]
        settings = {"port": 443, "concurrency": 2, "timeout_ms": 800, "latency_max": 150,
                    "speed_limit": 2, "download_bytes": 100000, "speed_timeout": 8}
        job = MOD.VpsTestJob(candidates, settings)
        with mock.patch.object(MOD, "_vps_probe_latency", side_effect=[(20, "SJC"), (40, "LAX")]), \
             mock.patch.object(MOD, "_vps_probe_speed", side_effect=[(100, "SJC"), (200, "LAX")]):
            job.run()
        snap = job.snapshot()
        self.assertEqual(snap["state"], "complete")
        self.assertEqual(len(snap["results"]), 2)
        self.assertEqual(snap["results"][0]["speed_mbps"], 200)

    def _server(self, target):
        server = MOD.OptimizerServer(("127.0.0.1", 0), MOD.OptimizerHandler)
        server.session_token = "test-token"
        server.candidates = [
            {"ip": "1.1.1.1", "ip_type": "IPv4", "source": "A", "port": 0},
            {"ip": "8.8.8.8", "ip_type": "IPv4", "source": "B", "port": 0},
        ]
        server.source_meta = {"key": "test", "name": "test", "cached": False, "fetched_at": 1}
        server.current_ips = ["1.1.1.1"]
        server.latency_max, server.speed_min, server.top_count, server.test_port = 150, 80, 1, 443
        server.candidate_limit, server.cache_dir, server.result_file, server.seed = 512, str(Path(target).parent), str(target), 1
        server.cancelled = server.applied = server.verbose = False
        server.client_results, server.vps_retry_results, server.vps_job = [], [], None
        server.client_test_ip = None
        server.vps_meta = {"ip": "127.0.0.1", "region": "测试"}
        server.preview_secret, server.preview, server.lock = b"x" * 32, None, threading.RLock()
        return server

    @staticmethod
    def _post(base, route, payload):
        request = urllib.request.Request(f"{base}/{route}", data=json.dumps(payload).encode(),
            headers={"Content-Type": "application/json"}, method="POST")
        with urllib.request.urlopen(request, timeout=3) as response: return json.load(response)

    def test_http_preview_digest_then_atomic_apply(self):
        with tempfile.TemporaryDirectory() as tmp:
            target = Path(tmp) / "result.json"
            server = self._server(target)
            thread = threading.Thread(target=server.serve_forever, daemon=True); thread.start()
            base = f"http://127.0.0.1:{server.server_address[1]}/test-token"
            with urllib.request.urlopen(f"{base}/config", timeout=3) as response:
                self.assertEqual(len(json.load(response)["candidates"]), 2)
            self._post(base, "client-results", {"client_ip": "8.8.4.4", "measurements": [
                {"ip": "8.8.8.8", "latency_ms": 30, "speed_mbps": 120, "loss_pct": 0}]})
            preview = self._post(base, "preview", {"selected": ["8.8.8.8"]})
            self.assertEqual(preview["added"], ["8.8.8.8"])
            self.assertEqual(preview["removed"], ["1.1.1.1"])
            applied = self._post(base, "apply", {"selected": ["8.8.8.8"], "digest": preview["digest"]})
            self.assertTrue(applied["ok"])
            thread.join(timeout=3); server.server_close()
            result = json.loads(target.read_text(encoding="utf-8"))
            self.assertEqual(result["selected"][0]["ip"], "8.8.8.8")
            self.assertEqual(result["client_test_ip"], "8.8.4.4")

    def test_preview_can_retain_current_ip_and_reject_foreign_retention(self):
        with tempfile.TemporaryDirectory() as tmp:
            target = Path(tmp) / "result.json"
            server = self._server(target)
            server.current_ips = ["9.9.9.9"]
            thread = threading.Thread(target=server.serve_forever, daemon=True); thread.start()
            base = f"http://127.0.0.1:{server.server_address[1]}/test-token"
            self._post(base, "client-results", {"client_ip": "8.8.4.4", "measurements": [
                {"ip": "8.8.8.8", "latency_ms": 30, "speed_mbps": 120, "loss_pct": 0}]})
            preview = self._post(base, "preview", {"selected": ["8.8.8.8"], "retained": ["9.9.9.9"]})
            self.assertEqual(preview["kept"], ["9.9.9.9"])
            self.assertEqual(preview["removed"], [])
            applied = self._post(base, "apply", {
                "selected": ["8.8.8.8"], "retained": ["9.9.9.9"], "digest": preview["digest"]})
            self.assertEqual([item["ip"] for item in applied["selected"]], ["8.8.8.8", "9.9.9.9"])
            thread.join(timeout=3); server.server_close()
            result = json.loads(target.read_text(encoding="utf-8"))
            self.assertEqual(result["selected"][1]["source"], "原优选池")

        with tempfile.TemporaryDirectory() as tmp:
            server = self._server(Path(tmp) / "result.json")
            thread = threading.Thread(target=server.serve_forever, daemon=True); thread.start()
            base = f"http://127.0.0.1:{server.server_address[1]}/test-token"
            request = urllib.request.Request(f"{base}/preview", data=b'{"selected":[],"retained":["8.8.8.8"]}',
                headers={"Content-Type": "application/json"}, method="POST")
            with self.assertRaises(urllib.error.HTTPError) as error: urllib.request.urlopen(request, timeout=3)
            self.assertEqual(error.exception.code, 400)
            server.shutdown(); thread.join(timeout=3); server.server_close()

    def test_client_results_require_actual_public_test_ip(self):
        with tempfile.TemporaryDirectory() as tmp:
            server = self._server(Path(tmp) / "result.json")
            thread = threading.Thread(target=server.serve_forever, daemon=True); thread.start()
            base = f"http://127.0.0.1:{server.server_address[1]}/test-token"
            request = urllib.request.Request(f"{base}/client-results", data=b'{"measurements":[]}',
                headers={"Content-Type": "application/json"}, method="POST")
            with self.assertRaises(urllib.error.HTTPError) as error: urllib.request.urlopen(request, timeout=3)
            self.assertEqual(error.exception.code, 400)
            server.shutdown(); thread.join(timeout=3); server.server_close()

    def test_preview_rejects_untested_candidate(self):
        with tempfile.TemporaryDirectory() as tmp:
            server = self._server(Path(tmp) / "result.json")
            thread = threading.Thread(target=server.serve_forever, daemon=True); thread.start()
            base = f"http://127.0.0.1:{server.server_address[1]}/test-token"
            request = urllib.request.Request(f"{base}/preview", data=b'{"selected":["1.1.1.1"]}',
                headers={"Content-Type": "application/json"}, method="POST")
            with self.assertRaises(urllib.error.HTTPError) as error: urllib.request.urlopen(request, timeout=3)
            self.assertEqual(error.exception.code, 400)
            server.shutdown(); thread.join(timeout=3); server.server_close()

    def test_result_file_permissions(self):
        with tempfile.TemporaryDirectory() as tmp:
            target = Path(tmp) / "result.json"
            MOD._atomic_json(target, {"selected": [{"ip": "1.1.1.1"}]})
            if os.name != "nt": self.assertEqual(target.stat().st_mode & 0o777, 0o600)


if __name__ == "__main__": unittest.main()
