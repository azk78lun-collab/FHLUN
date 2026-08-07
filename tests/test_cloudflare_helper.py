#!/usr/bin/env python3
import json
import os
import subprocess
import tempfile
import threading
import unittest
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
from urllib.parse import parse_qs, urlsplit


ROOT = Path(__file__).resolve().parents[1]


def extract_helper(target: Path) -> None:
    text = (ROOT / "lun.sh").read_text(encoding="utf-8")
    marker = 'cat > "$HOME/lun/cdn_cloudflare_api.py" <<\'PY\'\n'
    start = text.index(marker) + len(marker)
    end = text.index("\nPY\n", start)
    target.write_text(text[start:end] + "\n", encoding="utf-8")


class FakeCloudflareHandler(BaseHTTPRequestHandler):
    state = {"config": None, "dns_created": False, "dns_deleted": False, "tunnel_deleted": False}

    def log_message(self, _format, *_args):
        return

    def reply(self, result, status=200, result_info=None):
        payload = {"success": True, "errors": [], "messages": [], "result": result}
        if result_info is not None:
            payload["result_info"] = result_info
        raw = json.dumps(payload).encode()
        self.send_response(status)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(raw)))
        self.end_headers()
        self.wfile.write(raw)

    def read_json(self):
        size = int(self.headers.get("Content-Length", "0"))
        return json.loads(self.rfile.read(size) or b"{}")

    def do_GET(self):
        path = urlsplit(self.path).path
        if path == "/user/tokens/verify":
            self.reply({"status": "active"})
        elif path == "/zones":
            self.reply([{"id": "z1", "name": "example.com", "status": "active", "account": {"id": "a1", "name": "Test"}}], result_info={"total_pages": 1})
        elif path == "/zones/z1/dns_records":
            query = parse_qs(urlsplit(self.path).query)
            requested = query.get("name", [""])[0]
            if self.state["dns_created"] and requested == "argo-01.example.com":
                self.reply([{"id": "d1", "type": "CNAME", "name": "argo-01.example.com", "content": "t1.cfargotunnel.com", "ttl": 1, "proxied": True}])
            elif requested == "argo-01.example.com":
                self.reply([])
            else:
                self.reply([{"id": "origin", "type": "A", "name": "example.com", "content": "192.0.2.10", "ttl": 1, "proxied": True}])
        elif path == "/zones/z1/rulesets":
            self.reply([])
        elif path == "/zones/z1/settings/ssl":
            self.reply({"id": "ssl", "value": "full"})
        elif path == "/accounts/a1/cfd_tunnel":
            self.reply([])
        elif path == "/accounts/a1/cfd_tunnel/t1/token":
            self.reply("test-tunnel-token")
        else:
            self.send_error(404, path)

    def do_POST(self):
        path = urlsplit(self.path).path
        payload = self.read_json()
        if path == "/accounts/a1/cfd_tunnel":
            self.assert_payload(payload, {"name", "config_src"})
            self.reply({"id": "t1", "name": payload["name"]})
        elif path == "/zones/z1/dns_records":
            self.assert_payload(payload, {"type", "name", "content", "proxied"})
            self.state["dns_created"] = True
            self.reply({"id": "d1", **payload})
        else:
            self.send_error(404, path)

    def do_PUT(self):
        path = urlsplit(self.path).path
        payload = self.read_json()
        if path == "/accounts/a1/cfd_tunnel/t1/configurations":
            self.state["config"] = payload
            self.reply(payload)
        else:
            self.send_error(404, path)

    def do_DELETE(self):
        path = urlsplit(self.path).path
        if path == "/zones/z1/dns_records/d1":
            self.state["dns_deleted"] = True
            self.reply({"id": "d1"})
        elif path == "/accounts/a1/cfd_tunnel/t1":
            self.state["tunnel_deleted"] = True
            self.reply({"id": "t1"})
        else:
            self.send_error(404, path)

    def assert_payload(self, payload, required):
        if not required.issubset(payload):
            raise AssertionError((payload, required))


class CloudflareHelperTest(unittest.TestCase):
    def setUp(self):
        FakeCloudflareHandler.state = {"config": None, "dns_created": False, "dns_deleted": False, "tunnel_deleted": False}
        self.server = ThreadingHTTPServer(("127.0.0.1", 0), FakeCloudflareHandler)
        self.thread = threading.Thread(target=self.server.serve_forever, daemon=True)
        self.thread.start()
        self.temp = tempfile.TemporaryDirectory()
        self.root = Path(self.temp.name)
        self.helper = self.root / "helper.py"
        self.tunnel_state = self.root / "tunnel.json"
        extract_helper(self.helper)
        self.env = os.environ.copy()
        self.env.update({
            "CF_LUN_API_BASE": f"http://127.0.0.1:{self.server.server_port}",
            "CF_LUN_TOKEN": "test-token-abcdefghijklmnopqrstuvwxyz",
            "CF_LUN_HOST": "example.com",
            "CF_LUN_ZONE": "example.com",
            "CF_LUN_ORIGIN_IPS": "192.0.2.10",
            "CF_LUN_TUNNEL_HOST": "argo-01.example.com",
            "CF_LUN_TUNNEL_PORT": "8080",
            "CF_LUN_TUNNEL_STATE": str(self.tunnel_state),
        })

    def tearDown(self):
        self.server.shutdown()
        self.server.server_close()
        self.thread.join(timeout=2)
        self.temp.cleanup()

    def run_helper(self, action):
        return subprocess.run(
            [os.sys.executable, str(self.helper), action], env=self.env,
            text=True, capture_output=True, check=True,
        ).stdout

    def test_discovery_preflight_tunnel_and_rollback(self):
        self.assertIn("ZONE=example.com|z1|a1|Test", self.run_helper("zones"))
        self.assertIn("HOST=example.com|A|yes", self.run_helper("hosts"))
        self.assertIn("PREFLIGHT=ok", self.run_helper("preflight"))

        output = self.run_helper("tunnel-deploy")
        self.assertIn("TUNNEL_HOST=argo-01.example.com", output)
        self.assertIn("TUNNEL_TOKEN=test-tunnel-token", output)
        ingress = FakeCloudflareHandler.state["config"]["config"]["ingress"]
        self.assertEqual(ingress[0]["service"], "http://localhost:8080")
        self.assertEqual(ingress[-1]["service"], "http_status:404")
        self.assertTrue(self.tunnel_state.is_file())

        self.assertIn("TUNNEL_ROLLBACK=ok", self.run_helper("tunnel-rollback"))
        self.assertTrue(FakeCloudflareHandler.state["dns_deleted"])
        self.assertTrue(FakeCloudflareHandler.state["tunnel_deleted"])


if __name__ == "__main__":
    unittest.main()
