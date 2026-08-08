#!/usr/bin/env python3
import importlib.util
import json
import os
import threading
import urllib.request
import tempfile
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
SPEC = importlib.util.spec_from_file_location("lun_cdn_optimizer", ROOT / "lun_cdn_optimizer.py")
MOD = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(MOD)


class OptimizerTests(unittest.TestCase):
    def test_page_exposes_editable_thresholds_and_live_stages(self):
        self.assertIn('id="latencyInput"', MOD.PAGE)
        self.assertIn('id="speedInput"', MOD.PAGE)
        self.assertIn("等待延迟", MOD.PAGE)
        self.assertIn("测速中", MOD.PAGE)

    def test_thresholds_and_speed_weighted_rank(self):
        candidates = ["1.1.1.1", "2.2.2.2", "3.3.3.3", "4.4.4.4"]
        selected, accepted = MOD.rank_results(
            [
                {"ip": "1.1.1.1", "latency_ms": 40, "speed_mbps": 90},
                {"ip": "2.2.2.2", "latency_ms": 95, "speed_mbps": 190},
                {"ip": "3.3.3.3", "latency_ms": 151, "speed_mbps": 500},
                {"ip": "4.4.4.4", "latency_ms": 20, "speed_mbps": 79.99},
            ],
            candidates,
            latency_max=150,
            speed_min=80,
            top_count=5,
        )
        self.assertEqual([item["ip"] for item in selected], ["2.2.2.2", "1.1.1.1"])
        self.assertEqual(len(accepted), 2)

    def test_exact_thresholds_are_accepted_and_untrusted_ip_is_ignored(self):
        selected, _ = MOD.rank_results(
            [
                {"ip": "1.1.1.1", "latency_ms": 150, "speed_mbps": 80},
                {"ip": "9.9.9.9", "latency_ms": 1, "speed_mbps": 9999},
            ],
            ["1.1.1.1"],
            latency_max=150,
            speed_min=80,
            top_count=5,
        )
        self.assertEqual([item["ip"] for item in selected], ["1.1.1.1"])

    def test_candidate_generation_from_cidr_is_unique(self):
        with tempfile.TemporaryDirectory() as tmp:
            source = Path(tmp) / "source.txt"
            source.write_text("108.162.198.0/24\n162.159.38.0/24\n", encoding="utf-8")
            values = MOD.load_candidates("unused", 64, source_file=str(source), seed=7)
        self.assertEqual(len(values), 64)
        self.assertEqual(len(set(values)), 64)
        for value in values:
            self.assertTrue(
                MOD.ipaddress.ip_address(value) in MOD.ipaddress.ip_network("108.162.198.0/24")
                or MOD.ipaddress.ip_address(value) in MOD.ipaddress.ip_network("162.159.38.0/24")
            )

    def test_result_file_permissions_and_extract(self):
        with tempfile.TemporaryDirectory() as tmp:
            target = Path(tmp) / "result.json"
            MOD._atomic_json(target, {"selected": [{"ip": "1.1.1.1"}]})
            self.assertEqual(json.loads(target.read_text(encoding="utf-8"))["selected"][0]["ip"], "1.1.1.1")
            if os.name != "nt":
                self.assertEqual(target.stat().st_mode & 0o777, 0o600)

    def test_http_session_applies_server_validated_results(self):
        with tempfile.TemporaryDirectory() as tmp:
            target = Path(tmp) / "result.json"
            server = MOD.OptimizerServer(("127.0.0.1", 0), MOD.OptimizerHandler)
            server.session_token = "test-token"
            server.candidates = ["1.1.1.1", "2.2.2.2"]
            server.latency_max = 150
            server.speed_min = 80
            server.top_count = 1
            server.source = "test"
            server.result_file = str(target)
            server.cancelled = False
            server.applied = False
            server.verbose = False
            server.public_config = {"candidates": server.candidates}
            thread = threading.Thread(target=server.serve_forever, daemon=True)
            thread.start()
            base = f"http://127.0.0.1:{server.server_address[1]}/test-token"
            with urllib.request.urlopen(f"{base}/config", timeout=3) as response:
                self.assertEqual(json.load(response)["candidates"], server.candidates)
            payload = json.dumps(
                {
                    "latency_max": 100,
                    "speed_min": 150,
                    "measurements": [
                        {"ip": "1.1.1.1", "latency_ms": 30, "speed_mbps": 90},
                        {"ip": "2.2.2.2", "latency_ms": 80, "speed_mbps": 180},
                    ]
                }
            ).encode("utf-8")
            request = urllib.request.Request(
                f"{base}/apply",
                data=payload,
                headers={"Content-Type": "application/json"},
                method="POST",
            )
            with urllib.request.urlopen(request, timeout=3) as response:
                self.assertTrue(json.load(response)["ok"])
            thread.join(timeout=3)
            server.server_close()
            self.assertFalse(thread.is_alive())
            result = json.loads(target.read_text(encoding="utf-8"))
            self.assertEqual(result["selected"][0]["ip"], "2.2.2.2")
            self.assertEqual(result["latency_max_ms"], 100)
            self.assertEqual(result["speed_min_mbps"], 150)


if __name__ == "__main__":
    unittest.main()
