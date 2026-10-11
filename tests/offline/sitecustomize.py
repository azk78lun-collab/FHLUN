"""Test-only network fence: allow local fixtures, never contact a production host."""
import errno
import ipaddress
import socket

_getaddrinfo = socket.getaddrinfo
_connect = socket.socket.connect
_connect_ex = socket.socket.connect_ex


def _local(host):
    if isinstance(host, bytes):
        host = host.decode("ascii", "strict")
    if host in (None, "", "localhost"):
        return True
    try:
        return ipaddress.ip_address(str(host).split("%", 1)[0]).is_loopback
    except ValueError:
        return False


def _offline_getaddrinfo(host, *args, **kwargs):
    if not _local(host):
        raise OSError(errno.ENETUNREACH, "offline tests reject non-loopback DNS/network")
    return _getaddrinfo(host, *args, **kwargs)


def _offline_connect(self, address):
    if self.family in (socket.AF_INET, socket.AF_INET6) and not _local(address[0]):
        raise OSError(errno.ENETUNREACH, "offline tests reject non-loopback connections")
    return _connect(self, address)


def _offline_connect_ex(self, address):
    if self.family in (socket.AF_INET, socket.AF_INET6) and not _local(address[0]):
        return errno.ENETUNREACH
    return _connect_ex(self, address)


socket.getaddrinfo = _offline_getaddrinfo
socket.socket.connect = _offline_connect
socket.socket.connect_ex = _offline_connect_ex
