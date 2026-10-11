import errno
import socket
import sys
import unittest


class OfflineNetworkTests(unittest.TestCase):
    def setUp(self):
        guard = sys.modules.get("sitecustomize")
        if not guard or not hasattr(guard, "_offline_connect"):
            self.skipTest("run with tests/offline in PYTHONPATH to verify the network fence")

    def test_non_loopback_dns_and_connections_are_rejected(self):
        with self.assertRaises(OSError):
            socket.getaddrinfo("production.example.invalid", 443)
        with socket.socket() as connection:
            with self.assertRaises(OSError) as error:
                connection.connect(("8.8.8.8", 443))
            self.assertEqual(error.exception.errno, errno.ENETUNREACH)
            self.assertEqual(connection.connect_ex(("8.8.8.8", 443)), errno.ENETUNREACH)

    def test_local_fixtures_can_still_connect(self):
        with socket.socket() as listener:
            listener.bind(("127.0.0.1", 0))
            listener.listen(1)
            with socket.create_connection(listener.getsockname(), timeout=1) as client:
                with listener.accept()[0] as server:
                    client.sendall(b"fixture")
                    self.assertEqual(server.recv(7), b"fixture")
