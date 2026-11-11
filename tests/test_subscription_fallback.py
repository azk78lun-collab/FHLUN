import ast
import http.client
import pathlib
import re
import socket
import subprocess
import sys
import tempfile
import time
import unittest


SCRIPT = pathlib.Path(__file__).resolve().parents[1] / 'lun.sh'
SOURCE = SCRIPT.read_text(encoding='utf-8').split('ensure_subscription_httpd_fallback(){', 1)[1].split("<<'PY'\n", 1)[1].split('\nPY\n', 1)[0]


class SubscriptionFallbackTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.root = pathlib.Path(self.tmp.name)
        (self.root / 'server.py').write_text(SOURCE, encoding='utf-8')
        (self.root / 'subtoken.log').write_text('test-subscription-token')
        for name in ('jhsub.txt', 'clmi.yaml', 'sbox.json'):
            (self.root / name).write_text('fixture-' + name)
        with socket.socket() as sock:
            sock.bind(('127.0.0.1', 0))
            self.port = sock.getsockname()[1]
        self.proc = subprocess.Popen([sys.executable, str(self.root / 'server.py'), '--root', str(self.root), '--port', str(self.port)], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        self.addCleanup(self.stop)
        deadline = time.monotonic() + 8
        while time.monotonic() < deadline:
            try:
                with socket.create_connection(('127.0.0.1', self.port), timeout=.2):
                    return
            except OSError:
                if self.proc.poll() is not None:
                    self.fail('subscription process exited before listening')
                time.sleep(.05)
        self.fail('subscription process did not listen')

    def stop(self):
        self.proc.terminate()
        self.proc.wait(timeout=5)

    def request(self, path, method='GET'):
        conn = http.client.HTTPConnection('127.0.0.1', self.port, timeout=2)
        try:
            conn.request(method, path)
            response = conn.getresponse()
            return response.status, response.read(), dict(response.getheaders())
        finally:
            conn.close()

    def test_python36_syntax(self):
        ast.parse(SOURCE, feature_version=(3, 6))

    def test_only_token_scoped_subscription_files_are_served(self):
        for name in ('jhsub.txt', 'clmi.yaml', 'sbox.json'):
            status, data, headers = self.request('/test-subscription-token/' + name)
            self.assertEqual(status, 200)
            self.assertEqual(data, ('fixture-' + name).encode())
            self.assertEqual(headers['Cache-Control'], 'no-store')
        status, data, headers = self.request('/test-subscription-token/jhsub.txt', 'HEAD')
        self.assertEqual(status, 200)
        self.assertEqual(data, b'')
        self.assertGreater(int(headers['Content-Length']), 0)
        for path in ('/', '/test-subscription-token/', '/wrong/jhsub.txt', '/test-subscription-token/subtoken.log', '/test-subscription-token/../subtoken.log', '/test-subscription-token/%2e%2e%2fsubtoken.log'):
            self.assertEqual(self.request(path)[0], 404, path)

    def test_slow_connection_does_not_block_subscription(self):
        with socket.create_connection(('127.0.0.1', self.port), timeout=2) as slow:
            slow.sendall(b'GET /test-subscription-token/jhsub.txt HTTP/1.0\r\n')
            self.assertEqual(self.request('/test-subscription-token/jhsub.txt')[0], 200)

    @unittest.skipUnless(sys.platform.startswith('linux'), 'POSIX launcher test')
    def test_launcher_uses_fallback_when_busybox_has_no_httpd(self):
        launcher = re.search(r'^start_subscription_httpd\(\)\{.*?(?=^[A-Za-z_][A-Za-z_0-9]*\(\)\{)', SCRIPT.read_text(encoding='utf-8'), re.M | re.S).group()
        shell = r'''
set -eu
export HOME="$1"
red_line(){ echo "$*" >&2; }
valid_port_value(){ [ "$1" = 42290 ]; }
busybox(){ echo cat; }
busybox-extras(){ echo cat; }
ensure_subscription_httpd_fallback(){ : > "$HOME/fallback-selected"; }
nohup(){ printf '%s\n' "$*" > "$HOME/launch-command"; }
'''+launcher+r'''
start_subscription_httpd 42290
wait
test -f "$HOME/fallback-selected"
grep -q 'subscription_httpd.py --root' "$HOME/launch-command"
test "$(stat -c %a "$HOME/lun/subscription_httpd-42290.log")" = 600
'''
        result = subprocess.run(['bash', '-c', shell, 'test', str(self.root)], capture_output=True, text=True)
        self.assertEqual(result.returncode, 0, result.stderr)


if __name__ == '__main__':
    unittest.main()
