"""Optional Xray transport smoke test. All endpoints are temporary and local."""

import contextlib
import hashlib
import http.server
import json
import os
from pathlib import Path
import re
import socket
import ssl
import subprocess
import tempfile
import threading
import time
import unittest


XRAY = os.environ.get("LUN_TEST_XRAY")
HOST = "tunnel.example.test"
DEVICE = "1d09e458-d6e0-4a1d-920d-361b184c0768"
FLOW = "xtls-rprx-vision"


class Origin(http.server.BaseHTTPRequestHandler):
    def do_GET(self):
        self.send_response(200)
        self.send_header("Content-Length", str(len(b"Lun local transport fixture")))
        self.end_headers()
        self.wfile.write(b"Lun local transport fixture")

    def log_message(self, *args):
        pass


@contextlib.contextmanager
def bound_ports(count):
    with contextlib.ExitStack() as resources:
        ports = []
        for _ in range(count):
            sock = resources.enter_context(socket.socket())
            sock.bind(("127.0.0.1", 0))
            ports.append(sock.getsockname()[1])
    yield ports


@unittest.skipUnless(XRAY, "optional real Xray binary not supplied")
class UpstreamXrayTests(unittest.TestCase):
    def test_ws_and_xhttp_vision_over_local_connections(self):
        with tempfile.TemporaryDirectory() as temp, contextlib.ExitStack() as resources:
            root = Path(temp)
            origin = resources.enter_context(http.server.ThreadingHTTPServer(("127.0.0.1", 0), Origin))
            threading.Thread(target=origin.serve_forever, daemon=True).start()
            resources.callback(origin.shutdown)
            keys = subprocess.check_output([XRAY, "vlessenc"], timeout=10, text=True)
            decryption = re.findall(r'"decryption": "([^"]+)"', keys)[-1]
            encryption = re.findall(r'"encryption": "([^"]+)"', keys)[-1]
            cert = root / "edge"
            subprocess.run([XRAY, "tls", "cert", "-domain", HOST, "-name", HOST,
                            "-file", str(cert)], capture_output=True, check=True, timeout=15)
            cert_digest = hashlib.sha256(ssl.PEM_cert_to_DER_cert(
                cert.with_suffix(".crt").read_text(encoding="ascii"),
            )).hexdigest()

            def start(label, inbounds, outbounds):
                path = root / (label + ".json")
                path.write_text(json.dumps({"log": {"loglevel": "info"},
                                            "inbounds": inbounds, "outbounds": outbounds}), encoding="utf-8")
                # The loopback TLS relay simulates cloudflared, not Xray's Linux TCP splice.
                env = dict(os.environ, XRAY_BUF_SPLICE="disable")
                with path.with_suffix(".log").open("wb") as log:
                    proc = subprocess.Popen([XRAY, "run", "-c", str(path)], stdout=log, stderr=log, env=env)
                def stop():
                    if proc.poll() is None:
                        proc.kill()
                    proc.wait(timeout=5)
                resources.callback(stop)
                deadline = time.monotonic() + 7
                while proc.poll() is None and time.monotonic() < deadline:
                    try:
                        with socket.create_connection(("127.0.0.1", inbounds[0]["port"]), timeout=0.2):
                            return
                    except OSError:
                        time.sleep(0.05)
                self.fail(path.with_suffix(".log").read_text(encoding="utf-8", errors="replace"))

            def inbound(port, protocol, settings, stream=None):
                result = {"listen": "127.0.0.1", "port": port, "protocol": protocol, "settings": settings}
                if stream is not None:
                    result["streamSettings"] = stream
                return result

            with bound_ports(6) as (ws, xhttp, edge, ws_client, xhttp_client, old_client):
                ws_path, xhttp_path = "/" + DEVICE + "-vw", "/" + DEVICE + "-vx"
                ws_stream = {"network": "ws", "wsSettings": {"path": ws_path}}
                origin_xhttp = {"network": "xhttp", "xhttpSettings": {"path": xhttp_path, "mode": "auto"}}
                tls = {"certificates": [{"certificateFile": str(cert.with_suffix(".crt")),
                                         "keyFile": str(cert.with_suffix(".key"))}]}
                edge_stream = {"network": "tcp", "security": "tls", "tlsSettings": tls}
                auth = {"clients": [{"id": DEVICE, "flow": FLOW}], "decryption": decryption}
                start("server", [
                    inbound(ws, "vless", auth, ws_stream),
                    inbound(xhttp, "vless", auth, origin_xhttp),
                    inbound(edge, "dokodemo-door", {"address": "127.0.0.1", "port": xhttp, "network": "tcp"}, edge_stream),
                ], [{"protocol": "freedom", "settings": {"finalRules": [
                    {"action": "allow", "ip": ["127.0.0.1/32"], "port": origin.server_port},
                ]}}])
                argo_stream = {
                    "network": "xhttp", "security": "tls",
                    "tlsSettings": {"serverName": HOST, "alpn": ["http/1.1"],
                                    "pinnedPeerCertSha256": cert_digest},
                    "xhttpSettings": {"host": HOST, "path": xhttp_path, "mode": "packet-up"},
                }
                for name, local, entry, stream, flow in (
                    ("ws-vision", ws_client, ws, ws_stream, FLOW),
                    ("xhttp-tls-edge", xhttp_client, edge, argo_stream, FLOW),
                    ("old-ws", old_client, ws, ws_stream, ""),
                ):
                    start(name, [inbound(local, "socks", {"auth": "noauth", "udp": False})],
                          [{"protocol": "vless", "streamSettings": stream, "settings": {
                              "vnext": [{"address": "127.0.0.1", "port": entry,
                                         "users": [{"id": DEVICE, "flow": flow, "encryption": encryption}]}],
                          }}])
                    probe = subprocess.run(["curl", "-fsS", "--noproxy", "", "--max-time", "7",
                                            "--socks5", "127.0.0.1:" + str(local),
                                            "http://127.0.0.1:" + str(origin.server_port)],
                                           capture_output=True, timeout=12)
                    if name == "old-ws":
                        self.assertNotEqual(probe.returncode, 0)
                    else:
                        self.assertEqual(probe.returncode, 0, name + ": " + probe.stderr.decode(errors="replace")
                                         + "\n" + (root / (name + ".log")).read_text(encoding="utf-8", errors="replace")
                                         + "\n" + (root / "server.log").read_text(encoding="utf-8", errors="replace"))
                        self.assertEqual(probe.stdout, b"Lun local transport fixture")
