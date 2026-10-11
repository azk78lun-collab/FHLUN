import http.client
import http.server
import importlib.util
import shutil
import socket
import ssl
import subprocess
import tempfile
import threading
import time
import unittest
from pathlib import Path


SPEC = importlib.util.spec_from_file_location("lun_agent", Path(__file__).resolve().parents[1] / "lun_agent.py")
agent = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(agent)


class Handler(http.server.BaseHTTPRequestHandler):
    def do_GET(self):
        self.send_response(200)
        self.send_header("Content-Length", "2")
        self.end_headers()
        self.wfile.write(b"ok")

    def log_message(self, *_args):
        pass


class SubscriptionServerTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        if not shutil.which("openssl"):
            raise unittest.SkipTest("openssl is required for local TLS fixtures")
        cls.temp = tempfile.TemporaryDirectory()
        root = Path(cls.temp.name)
        cls.certificate, cls.key = root / "cert.pem", root / "key.pem"
        subprocess.run([
            "openssl", "req", "-x509", "-newkey", "rsa:2048", "-nodes", "-days", "1",
            "-subj", "/CN=localhost", "-keyout", str(cls.key), "-out", str(cls.certificate),
        ], check=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)

    @classmethod
    def tearDownClass(cls):
        cls.temp.cleanup()

    def start_server(self, tls=True, ipv6=False):
        cls = agent.DualStackServer if ipv6 else agent.SubscriptionServer
        try:
            server = cls(("::1" if ipv6 else "127.0.0.1", 0), Handler)
        except OSError as exc:
            if ipv6:
                self.skipTest(str(exc))
            raise
        server.handshake_timeout = 0.4
        server.request_timeout = 0.4
        if tls:
            context = ssl.SSLContext(ssl.PROTOCOL_TLS_SERVER)
            context.load_cert_chain(self.certificate, self.key)
            server.tls_context = context
        worker = threading.Thread(target=server.serve_forever, kwargs={"poll_interval": 0.05}, daemon=True)
        worker.start()
        self.addCleanup(server.server_close)
        self.addCleanup(worker.join, 1)
        self.addCleanup(server.shutdown)
        return server

    def request(self, server, tls=True):
        host, port = server.server_address[:2]
        connection = (http.client.HTTPSConnection(host, port, timeout=1, context=ssl._create_unverified_context())
                      if tls else http.client.HTTPConnection(host, port, timeout=1))
        try:
            connection.request("GET", "/")
            response = connection.getresponse()
            self.assertEqual(response.status, 200)
            self.assertEqual(response.read(), b"ok")
        finally:
            connection.close()

    def test_slow_tls_does_not_block_other_requests_or_shutdown(self):
        server = self.start_server()
        slow = socket.create_connection(server.server_address)
        self.addCleanup(slow.close)
        self.request(server)
        started = time.monotonic()
        server.shutdown()
        self.assertLess(time.monotonic() - started, 0.5)

    def test_tls_and_header_deadlines_close_stalled_connections(self):
        server = self.start_server()
        with socket.create_connection(server.server_address) as slow:
            slow.settimeout(1.5)
            self.assertEqual(slow.recv(1), b"")
        context = ssl._create_unverified_context()
        with context.wrap_socket(socket.create_connection(server.server_address), server_hostname="localhost") as slow:
            slow.settimeout(1.5)
            slow.sendall(b"GET / HTTP/1.1\r\n")
            self.assertEqual(slow.recv(1), b"")
        self.request(server)

    def test_connection_limit_drops_excess_without_blocking(self):
        server = self.start_server()
        server._connection_slots = threading.BoundedSemaphore(1)
        self.assertTrue(server._connection_slots.acquire())
        try:
            with socket.create_connection(server.server_address) as excess:
                excess.settimeout(1)
                self.assertEqual(excess.recv(1), b"")
        finally:
            server._connection_slots.release()
        self.request(server)

    def test_plain_http_and_ipv6_remain_usable(self):
        self.request(self.start_server(tls=False), tls=False)
        self.request(self.start_server(ipv6=True))


if __name__ == "__main__":
    unittest.main()
