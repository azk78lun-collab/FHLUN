"""Opt-in loopback test with a hash-verified official Sing-box binary."""

import contextlib
import http.server
import json
import os
from pathlib import Path
import re
import socket
import subprocess
import tempfile
import threading
import time
import unittest


CORE = os.environ.get("LUN_TEST_SNELL")
MIHOMO = os.environ.get("LUN_TEST_MIHOMO")
STATS = os.environ.get("LUN_TEST_SB_STATS")
BASH = os.environ.get("LUN_TEST_BASH", "bash")
ROOT = Path(__file__).resolve().parents[1]
UUID = "1d09e458-d6e0-4a1d-920d-361b184c0768"


def free_port():
    with socket.socket() as sock:
        sock.bind(("127.0.0.1", 0))
        return sock.getsockname()[1]


class Origin(http.server.BaseHTTPRequestHandler):
    def do_GET(self):
        body = b"Lun Snell v6"
        self.send_response(200)
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def log_message(self, *args):
        pass


@unittest.skipUnless(CORE, "optional real Sing-box binary not supplied")
class SnellCoreTests(unittest.TestCase):
    def test_legacy_standard_configs_and_stats_feature(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            file = root / "legacy.json"
            key, cert = root / "tls.key", root / "tls.crt"
            subprocess.run(["openssl", "req", "-x509", "-newkey", "rsa:2048", "-nodes", "-days", "1",
                            "-subj", "/CN=fixture.example.test", "-keyout", str(key), "-out", str(cert)],
                           check=True, capture_output=True, timeout=20)
            tls = {"enabled": True, "certificate_path": str(cert), "key_path": str(key)}
            reality_keys = subprocess.check_output([CORE, "generate", "reality-keypair"], text=True, timeout=10)
            reality_key = re.search(r"PrivateKey:\s*([^\s]+)", reality_keys).group(1)
            reality = {"enabled": True, "server_name": "fixture.example.test", "reality": {
                "enabled": True, "private_key": reality_key, "short_id": ["0123456789abcdef"],
                "handshake": {"server": "127.0.0.1", "server_port": 443},
            }}
            secured = [
                ("anytls", "anytls-sb", {"password": UUID}, tls),
                ("anytls", "anyreality-sb", {"password": UUID}, reality),
                ("hysteria2", "hy2-sb", {"password": UUID}, tls),
                ("tuic", "tuic5-sb", {"uuid": UUID, "password": UUID}, tls),
                ("naive", "naive-sb", {"username": UUID, "password": UUID}, tls),
            ]
            with open(file, "w", encoding="utf-8") as output:
                json.dump({
                    "inbounds": [
                        {"type": "socks", "tag": "socks-sb", "listen": "127.0.0.1", "listen_port": 1080},
                        {"type": "vmess", "tag": "vmess-sb", "listen": "127.0.0.1", "listen_port": 1081,
                         "users": [{"uuid": UUID}], "transport": {"type": "ws", "path": "/" + UUID + "-vm"}},
                        {"type": "shadowsocks", "tag": "ss-2022", "listen": "127.0.0.1", "listen_port": 1082,
                         "method": "2022-blake3-aes-128-gcm", "password": "AAECAwQFBgcICQoLDA0ODw=="},
                    ] + [{"type": kind, "tag": tag, "listen": "127.0.0.1", "listen_port": 1083 + i,
                          "users": [user], "tls": security}
                         for i, (kind, tag, user, security) in enumerate(secured)],
                    "outbounds": [{"type": "direct", "tag": "direct"}],
                }, output)
            check = subprocess.run([CORE, "check", "-c", str(file)], capture_output=True, timeout=10)
            self.assertEqual(check.returncode, 0, check.stderr.decode(errors="replace"))
            version = subprocess.check_output([CORE, "version"], text=True, timeout=10)
            if STATS:
                self.assertIn("with_v2ray_api", version)

    @unittest.skipUnless(STATS, "optional Lun statistics helper not supplied")
    def test_lun_helper_reads_real_per_user_traffic(self):
        with tempfile.TemporaryDirectory() as directory, contextlib.ExitStack() as cleanup:
            origin = cleanup.enter_context(http.server.ThreadingHTTPServer(("127.0.0.1", 0), Origin))
            threading.Thread(target=origin.serve_forever, daemon=True).start()
            cleanup.callback(origin.shutdown)
            socks, api = free_port(), free_port()
            if socks == api:
                api = free_port()
            path = Path(directory) / "stats.json"
            path.write_text(json.dumps({
                "log": {"disabled": True},
                "inbounds": [{"type": "socks", "tag": "socks-sb", "listen": "127.0.0.1", "listen_port": socks,
                              "users": [{"username": "lun-fixture", "password": "test-password"}]}],
                "outbounds": [{"type": "direct", "tag": "direct"}],
                "experimental": {"v2ray_api": {"listen": f"127.0.0.1:{api}",
                                              "stats": {"enabled": True, "users": ["lun-fixture"]}}},
            }), encoding="utf-8")
            process = subprocess.Popen([CORE, "run", "-c", str(path)], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
            def stop():
                if process.poll() is None:
                    process.kill()
                process.wait(timeout=5)
            cleanup.callback(stop)
            query = [STATS, "--server", f"127.0.0.1:{api}", "--timeout", "1s"]
            for _ in range(5):
                ready = subprocess.run(query, capture_output=True, timeout=3)
                if ready.returncode == 0:
                    break
                time.sleep(0.1)
            self.assertEqual(ready.returncode, 0, ready.stderr.decode(errors="replace"))
            response = subprocess.run(["curl", "-fsS", "--noproxy", "", "--max-time", "5",
                                       "--socks5", f"127.0.0.1:{socks}", "--proxy-user", "lun-fixture:test-password",
                                       f"http://127.0.0.1:{origin.server_port}/"], capture_output=True, timeout=8)
            self.assertEqual(response.stdout, b"Lun Snell v6", response.stderr.decode(errors="replace"))
            counters = json.loads(subprocess.check_output(query + ["--reset"], timeout=5))["stat"]
            self.assertTrue(any(row["name"].startswith("user>>>lun-fixture>>>traffic>>>") and int(row["value"]) > 0
                                for row in counters))
            after = json.loads(subprocess.check_output(query, timeout=5)).get("stat", [])
            self.assertFalse(any(int(row.get("value", 0)) for row in after))

    def test_snell_linux_config_interop_bad_key_and_port_release(self):
        with tempfile.TemporaryDirectory() as directory, contextlib.ExitStack() as resources:
            root = Path(directory)
            origin = resources.enter_context(http.server.ThreadingHTTPServer(("127.0.0.1", 0), Origin))
            threading.Thread(target=origin.serve_forever, daemon=True).start()
            resources.callback(origin.shutdown)
            port = free_port()
            generated = json.loads(subprocess.check_output(
                [BASH, "tests/test_snell.sh", "--fixture", str(port)], cwd=ROOT, timeout=15,
            ))
            self.assertIn({"ip_is_private": True, "action": "reject"}, generated["route"]["rules"])
            # Test-only allow rule for the loopback fixture, not the production config.
            test_config = json.loads(json.dumps(generated))
            test_config["route"]["rules"].insert(0, {
                "ip_cidr": ["127.0.0.1/32"], "port": [origin.server_port], "outbound": "direct",
            })

            def config(label, cfg):
                path = root / (label + ".json")
                path.write_text(json.dumps(cfg), encoding="utf-8")
                return path

            def start(label, argv, listen):
                logpath = root / (label + ".log")
                with logpath.open("wb") as log:
                    proc = subprocess.Popen(argv, stdout=log, stderr=log)
                def stop():
                    if proc.poll() is None:
                        proc.terminate()
                        try:
                            proc.wait(timeout=3)
                        except subprocess.TimeoutExpired:
                            proc.kill()
                            proc.wait(timeout=3)
                resources.callback(stop)
                deadline = time.monotonic() + 6
                while proc.poll() is None and time.monotonic() < deadline:
                    try:
                        with socket.create_connection(("127.0.0.1", listen), timeout=0.2):
                            return stop
                    except OSError:
                        time.sleep(0.05)
                self.fail(logpath.read_text(encoding="utf-8", errors="replace"))

            checked = subprocess.run([CORE, "check", "-c", str(config("generated", generated))],
                                     capture_output=True, timeout=10)
            self.assertEqual(checked.returncode, 0, checked.stderr.decode(errors="replace"))
            stop_server = start("server", [CORE, "run", "-c", str(config("server", test_config))], port)
            def proxy_call(local):
                return subprocess.run(["curl", "-fsS", "--noproxy", "", "--max-time", "4", "--socks5",
                                       f"127.0.0.1:{local}", f"http://127.0.0.1:{origin.server_port}/"],
                                      capture_output=True, timeout=7)
            for correct in (False, True):
                local = free_port()
                outbound = {"type": "snell", "tag": "proxy", "server": "127.0.0.1", "server_port": port,
                            "psk": ("a" if correct else "b") * 64, "version": 6, "mode": "default", "reuse": True}
                client = {"inbounds": [{"type": "socks", "listen": "127.0.0.1", "listen_port": local}],
                          "outbounds": [outbound]}
                stop_client = start("client", [CORE, "run", "-c", str(config("client", client))], local)
                result = proxy_call(local)
                if correct:
                    self.assertEqual(result.returncode, 0, result.stderr.decode(errors="replace"))
                    self.assertEqual(result.stdout, b"Lun Snell v6")
                else:
                    self.assertNotEqual(result.returncode, 0)
                stop_client()
            if MIHOMO:
                local = free_port()
                proxy = {"name": "Snell", "type": "snell", "server": "127.0.0.1", "port": port,
                         "psk": "a" * 64, "version": 6, "mode": "default", "reuse": True, "udp": True}
                cfg = {"socks-port": local, "bind-address": "127.0.0.1", "proxies": [proxy], "rules": ["MATCH,Snell"]}
                start("mihomo", [MIHOMO, "-d", str(root), "-f", str(config("mihomo", cfg))], local)
                probe = proxy_call(local)
                self.assertEqual(probe.returncode, 0, probe.stderr.decode(errors="replace"))
                self.assertEqual(probe.stdout, b"Lun Snell v6")
            stop_server()
            with self.assertRaises(OSError):
                socket.create_connection(("127.0.0.1", port), timeout=0.2)
