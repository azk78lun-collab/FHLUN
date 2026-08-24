#!/usr/bin/env python3
"""FHLUN optional multi-server cluster controller and managed-node agent.

The module intentionally uses only Python's standard library and OpenSSL.  It
does not expose a shell API: remote mutations are validated structured actions
that map to fixed Lun commands and environment variables.
"""

from __future__ import annotations

import argparse
import base64
import binascii
import concurrent.futures
import contextlib
import datetime as dt
import getpass
import hashlib
import hmac
import http.client
import http.server
import ipaddress
import json
import os
import re
import secrets
import shutil
import signal
import socket
import sqlite3
import ssl
import subprocess
import sys
import tarfile
import tempfile
import threading
import time
import unicodedata
import urllib.parse
import urllib.request
import uuid
from pathlib import Path
from typing import Any, Callable, Iterable


VERSION = "0.2.2"
API_VERSION = 3
RESTART_EXIT_CODE = 75
JOIN_TTL = 15 * 60
BOOTSTRAP_TIMEOUT = 30
JOIN_REQUEST_TIMEOUT = 120
MAX_BODY = 4 * 1024 * 1024
ROLE_TRANSFER_CHUNK = 512 * 1024
ROLE_TRANSFER_MAX = 32 * 1024 * 1024
ROLE_TRANSFER_TTL = 15 * 60
FEDERATION_FANOUT = 10
FEDERATION_FANOUT_TTL = 180
PUBLIC_IP_SOURCES = (
    ("icanhazip", "https://icanhazip.com"),
    ("ipify", "https://api64.ipify.org"),
    ("amazon", "https://checkip.amazonaws.com"),
)
PUBLIC_IP_FAMILY_SOURCES = {
    4: (
        ("icanhazip-v4", "https://ipv4.icanhazip.com"),
        ("ipify-v4", "https://api.ipify.org"),
        ("amazon-v4", "https://checkip.amazonaws.com"),
    ),
    6: (
        ("icanhazip-v6", "https://ipv6.icanhazip.com"),
        ("ipify-v6", "https://api6.ipify.org"),
        ("ident-v6", "https://v6.ident.me"),
    ),
}
TLS_HANDSHAKE_TIMEOUT = 8
BACKUP_MAGIC = b"LUNCLUSTER1\0"
BACKUP_KDF_ITERATIONS = 300_000
SUBSCRIPTION_FILES = ("jhsub.txt", "clmi.yaml", "sbox.json")
CDN_POOL_MAX_ENTRIES = 64
CDN_POOL_MAX_TEXT = 8192
FEDERATION_EVENT_TYPES = {
    "member.upsert", "member.revoke", "node.metadata", "profile.upsert", "token.upsert",
    "token.delete", "user.upsert", "user.delete", "device.upsert", "device.delete",
    "authorization.upsert", "usage.absolute", "snapshot.head", "revocation.proof",
}
FEDERATION_USER_EVENT_TYPES = {
    "user.upsert", "user.delete", "device.upsert", "device.delete",
    "authorization.upsert", "token.upsert", "token.delete",
}
FEDERATION_USER_MAX = 1000
FEDERATION_DEVICE_MAX = 64
FEDERATION_PROTOCOLS = {"vl", "xh", "vx", "vw", "ss", "an", "ar", "vm", "so", "hy", "tu", "xu", "xc", "nv"}

COUNTRY_NAMES_ZH = {
    "AU": "澳大利亚", "CA": "加拿大", "DE": "德国", "FR": "法国", "GB": "英国",
    "HK": "中国香港", "JP": "日本", "KR": "韩国", "NL": "荷兰", "SG": "新加坡",
    "TW": "中国台湾", "US": "美国",
}
CITY_NAMES_ZH = {
    "frankfurt": "法兰克福", "hong kong": "香港", "london": "伦敦",
    "los angeles": "洛杉矶",
    "minoh": "大阪", "osaka": "大阪", "seoul": "首尔", "singapore": "新加坡",
    "tokyo": "东京",
}
PLACE_LABEL_ALIASES_ZH = {"日本-箕面": "日本-大阪", "箕面": "大阪"}
STATE_NAMES_ZH = {"online": "在线", "unreachable": "离线", "unknown": "未连接"}
PROXY_OUTBOUND_TYPES = {
    "vless", "vmess", "shadowsocks", "anytls", "tuic", "hysteria2", "socks", "naive"
}
PORT_ENV_FIELDS = {
    "vlpt", "vmpt", "vwpt", "hypt", "tupt", "xhpt", "vxpt", "anpt",
    "sspt", "arpt", "sopt", "xupt", "xcpt", "nvpt", "cdnpt",
}
LUN_ENV_FIELDS = {
    *PORT_ENV_FIELDS,
    "uuid", "reym", "cdnym", "cfip", "argo", "agn", "agk", "ippz", "warp",
    "name", "oap", "addym", "addout", "ptmap", "portpool", "inpool", "outpool",
    "vpsmode", "argoip", "subipmode", "cdnmode", "cdnproto", "addrmode", "domain",
    "certmode", "acme_email", "acme_dns", "coremirror",
}
ACTION_NAMES = {
    "status.refresh", "subscription.refresh", "protocol.apply", "service.restart", "service.control",
    "core.update", "firewall.apply", "script.install", "agent.install", "snapshot.create",
    "snapshot.restore", "user.sync", "identity.apply", "lun.factory-reset", "lun.uninstall",
    "cluster.update-all",
    "role.stage", "role.discard", "role.promote", "role.rollback", "role.finalize",
    "role.children-commit", "role.children-revert", "controller.prepare",
    "controller.commit", "controller.abort", "controller.reassign",
    "cdn.pool.preview", "cdn.pool.apply",
    "federation.catchup", "federation.relay", "federation.snapshot",
}


class ClusterError(RuntimeError):
    pass


class FederationTransportError(ClusterError):
    """A retryable mTLS transport failure, distinct from a remote rejection."""



def utc_now() -> int:
    return int(time.time())


def iso_time(value: int | None) -> str:
    if not value:
        return "-"
    return dt.datetime.fromtimestamp(value, dt.timezone.utc).strftime("%Y-%m-%d %H:%M UTC")


def json_dumps(value: Any) -> str:
    return json.dumps(value, ensure_ascii=False, sort_keys=True, separators=(",", ":"))


def canonical_event_fields(event: dict[str, Any]) -> bytes:
    """The exact signed representation.  Keep this deliberately small and stable."""
    fields = {key: event[key] for key in (
        "author_id", "author_seq", "prev_hash", "lamport", "type", "entity_key", "payload", "created_at"
    )}
    return json_dumps(fields).encode("utf-8")


def event_hash(event: dict[str, Any]) -> str:
    return hashlib.sha256(canonical_event_fields(event) + b"." + str(event["signature"]).encode("ascii")).hexdigest()


def b64url(data: bytes) -> str:
    return base64.urlsafe_b64encode(data).decode().rstrip("=")


def b64decode(value: str) -> bytes:
    return base64.b64decode(value.encode(), validate=True)


def atomic_write(path: Path, data: str | bytes, mode: int = 0o600) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    payload = data.encode("utf-8") if isinstance(data, str) else data
    fd, temporary = tempfile.mkstemp(prefix=f".{path.name}.", dir=str(path.parent))
    try:
        with os.fdopen(fd, "wb") as handle:
            handle.write(payload)
            handle.flush()
            os.fsync(handle.fileno())
        os.chmod(temporary, mode)
        os.replace(temporary, path)
    finally:
        with contextlib.suppress(FileNotFoundError):
            os.unlink(temporary)


def display_width(value: str) -> int:
    return sum(2 if unicodedata.east_asian_width(char) in {"W", "F"} else 1 for char in value)


def display_pad(value: str, width: int) -> str:
    return value + " " * max(0, width - display_width(value))


def valid_port(value: int) -> bool:
    return 1 <= int(value) <= 65535


def normalize_host(value: str) -> str:
    host = value.strip()
    if host.startswith("[") and host.endswith("]"):
        host = host[1:-1]
    if not host or any(char in host for char in "/?#@ \t\r\n"):
        raise ClusterError("服务器地址格式无效")
    with contextlib.suppress(ValueError):
        return str(ipaddress.ip_address(host))
    if len(host) > 253 or not re.fullmatch(r"(?i)[a-z0-9](?:[a-z0-9.-]{0,251}[a-z0-9])?", host):
        raise ClusterError("服务器地址格式无效")
    return host.lower().rstrip(".")


def uri_host(host: str) -> str:
    return f"[{host}]" if ":" in host and not host.startswith("[") else host


def normalize_country_code(value: str) -> str:
    result = value.strip().upper()
    return result if re.fullmatch(r"[A-Z]{2}", result) else "ZZ"


def infer_country_code(value: str) -> str:
    label = safe_label(value)
    for code, name in COUNTRY_NAMES_ZH.items():
        if label == name or label.startswith(name + "-") or label.startswith(name + " "):
            return code
    return "ZZ"


def chinese_place(row: dict[str, Any]) -> str:
    code = normalize_country_code(str(row.get("country_code", "")))
    country = COUNTRY_NAMES_ZH.get(code, "")
    detail = canonical_place_label(str(row.get("city") or row.get("region") or ""))
    if detail:
        detail = CITY_NAMES_ZH.get(detail.lower(), detail if re.search(r"[\u3400-\u9fff]", detail) else "")
        detail = canonical_place_label(detail)
    if country and detail and (detail == country or detail.startswith(country + "-") or detail.startswith(country + " ")):
        return detail
    if country and detail:
        return f"{country}-{detail}"
    return country or detail or "未设置地区"


def numbered_place_labels(rows: Iterable[sqlite3.Row | dict[str, Any]]) -> dict[str, str]:
    items = [dict(row) for row in rows]
    items.sort(key=lambda row: (int(row.get("server_number") or row.get("number") or 0), str(row.get("id", ""))))
    groups: dict[str, list[dict[str, Any]]] = {}
    for row in items:
        groups.setdefault(chinese_place(row), []).append(row)
    labels: dict[str, str] = {}
    for place, members in groups.items():
        for index, row in enumerate(members, 1):
            labels[str(row.get("id", ""))] = place if len(members) == 1 else f"{place}{index}"
    return labels


def safe_label(value: str, limit: int = 80) -> str:
    value = " ".join(value.replace("\x00", "").split())
    return value[:limit]


def canonical_place_label(value: str) -> str:
    label = safe_label(value)
    return PLACE_LABEL_ALIASES_ZH.get(label, label)


def canonical_subscription_names(value: str) -> str:
    return value.replace("[日本-箕面]", "[日本-大阪]")


def canonicalize_subscription_value(value: Any) -> Any:
    if isinstance(value, str):
        return canonical_subscription_names(value)
    if isinstance(value, list):
        return [canonicalize_subscription_value(item) for item in value]
    if isinstance(value, dict):
        return {key: canonicalize_subscription_value(item) for key, item in value.items()}
    return value


def normalize_public_ip(value: str) -> str:
    text = str(value or "").strip().strip("[]")
    if "\n" in text:
        for line in text.splitlines():
            if line.startswith("ip="):
                text = line.split("=", 1)[1].strip()
                break
    try:
        address = ipaddress.ip_address(text)
    except ValueError as exc:
        raise ClusterError("公网 IP 格式无效") from exc
    if not address.is_global:
        raise ClusterError("只允许公网 IP 作为联邦地址")
    return address.compressed


def _fetch_public_ip(url: str, timeout: int = 4) -> str:
    request = urllib.request.Request(url, headers={"User-Agent": "Lun-Cluster/0.2"})
    with urllib.request.urlopen(request, timeout=timeout) as response:
        payload = response.read(512).decode("ascii", errors="ignore")
    return normalize_public_ip(payload)


def detect_public_ip(current_host: str = "", *,
                     fetcher: Callable[[str, int], str] | None = None) -> dict[str, Any]:
    """Confirm one public IP with a majority of fixed HTTPS observers."""
    fetch = fetcher or _fetch_public_ip
    observations: dict[str, str] = {}
    errors: dict[str, str] = {}

    def probe(item: tuple[str, str]) -> tuple[str, str]:
        name, url = item
        return name, normalize_public_ip(fetch(url, 4))

    with concurrent.futures.ThreadPoolExecutor(max_workers=len(PUBLIC_IP_SOURCES)) as executor:
        futures = {executor.submit(probe, item): item[0] for item in PUBLIC_IP_SOURCES}
        for future in concurrent.futures.as_completed(futures):
            name = futures[future]
            try:
                source, value = future.result()
                observations[source] = value
            except Exception as exc:
                errors[name] = str(exc)[-300:]
    counts: dict[str, int] = {}
    for value in observations.values():
        counts[value] = counts.get(value, 0) + 1
    current_family = 0
    with contextlib.suppress(ValueError):
        current_family = ipaddress.ip_address(str(current_host).strip().strip("[]")).version
    ranked = sorted(
        counts,
        key=lambda value: (-counts[value],
                           0 if ipaddress.ip_address(value).version == current_family else 1,
                           value),
    )
    candidate = ranked[0] if ranked and counts[ranked[0]] >= 2 else ""
    return {
        "confirmed": bool(candidate), "ip": candidate, "observations": observations,
        "errors": errors, "checked_at": utc_now(),
    }


def order_public_hosts(values: Iterable[Any], primary: str = "") -> list[str]:
    """Return unique public addresses with IPv4 first, then IPv6 and domains."""
    hosts: list[str] = []
    for value in [primary, *values]:
        text = str(value or "").strip().strip("[]")
        if not text:
            continue
        try:
            text = normalize_public_ip(text)
        except ClusterError:
            try:
                text = normalize_host(text)
            except ClusterError:
                continue
        if text not in hosts:
            hosts.append(text)

    def rank(host: str) -> tuple[int, str]:
        with contextlib.suppress(ValueError):
            return (0 if ipaddress.ip_address(host).version == 4 else 1, host)
        return (2, host)

    return sorted(hosts, key=rank)


def detect_public_hosts(*, fetcher: Callable[[str, int], str] | None = None) -> dict[str, Any]:
    """Cross-check each address family independently and prefer IPv4 for transport."""
    fetch = fetcher or _fetch_public_ip
    observations: dict[str, str] = {}
    errors: dict[str, str] = {}

    def probe(family: int, item: tuple[str, str]) -> tuple[str, str]:
        name, url = item
        value = normalize_public_ip(fetch(url, 4))
        if ipaddress.ip_address(value).version != family:
            raise ClusterError(f"探测结果不是 IPv{family}")
        return name, value

    source_count = sum(len(items) for items in PUBLIC_IP_FAMILY_SOURCES.values())
    with concurrent.futures.ThreadPoolExecutor(max_workers=source_count) as executor:
        futures = {
            executor.submit(probe, family, item): item[0]
            for family, items in PUBLIC_IP_FAMILY_SOURCES.items() for item in items
        }
        for future in concurrent.futures.as_completed(futures):
            name = futures[future]
            try:
                source, value = future.result()
                observations[source] = value
            except Exception as exc:
                errors[name] = str(exc)[-300:]
    confirmed: list[str] = []
    for family in (4, 6):
        counts: dict[str, int] = {}
        for value in observations.values():
            if ipaddress.ip_address(value).version == family:
                counts[value] = counts.get(value, 0) + 1
        ranked = sorted(counts, key=lambda value: (-counts[value], value))
        if ranked and counts[ranked[0]] >= 2:
            confirmed.append(ranked[0])
    hosts = order_public_hosts(confirmed)
    return {
        "confirmed": bool(hosts), "ip": hosts[0] if hosts else "", "ips": hosts,
        "observations": observations, "errors": errors, "checked_at": utc_now(),
    }


def safe_slug(value: str) -> str:
    value = re.sub(r"[^A-Za-z0-9_-]+", "-", value.strip()).strip("-")
    return value[:48] or "group"


def random_node_id() -> str:
    return uuid.uuid4().hex


def short_id(value: str) -> str:
    return value[:8]


def parse_join_uri(value: str) -> dict[str, Any]:
    parsed = urllib.parse.urlsplit(value.strip())
    if parsed.scheme != "lunjoin" or not parsed.hostname or not parsed.port:
        raise ClusterError("加入地址格式错误，应以 lunjoin:// 开头并包含端口")
    node_id = parsed.path.strip("/")
    query = urllib.parse.parse_qs(parsed.query, strict_parsing=True)
    token = query.get("token", [""])[0]
    fingerprint = query.get("fp", [""])[0].lower().replace(":", "")
    expires = query.get("exp", ["0"])[0]
    if not re.fullmatch(r"[0-9a-f]{32}", node_id):
        raise ClusterError("加入地址中的节点 ID 无效")
    if len(token) < 32 or not re.fullmatch(r"[A-Za-z0-9_-]+", token):
        raise ClusterError("加入地址中的一次性令牌无效")
    if not re.fullmatch(r"[0-9a-f]{64}", fingerprint):
        raise ClusterError("加入地址中的 TLS 指纹无效")
    try:
        expiry = int(expires)
    except ValueError as exc:
        raise ClusterError("加入地址中的到期时间无效") from exc
    if expiry < utc_now():
        raise ClusterError("加入地址已经过期，请在子 VPS 重新生成")
    return {
        "host": normalize_host(parsed.hostname), "port": parsed.port, "node_id": node_id,
        "token": token, "fingerprint": fingerprint, "expires": expiry,
    }


def make_join_uri(host: str, port: int, node_id: str, token: str, fingerprint: str, expires: int) -> str:
    return (
        f"lunjoin://{uri_host(normalize_host(host))}:{int(port)}/{node_id}"
        f"?token={urllib.parse.quote(token)}&fp={fingerprint}&exp={expires}"
    )


class FileLock:
    def __init__(self, path: Path, timeout: float = 30.0):
        self.path = path
        self.timeout = timeout
        self.fd: int | None = None

    def __enter__(self) -> "FileLock":
        deadline = time.monotonic() + self.timeout
        self.path.parent.mkdir(parents=True, exist_ok=True)
        while True:
            try:
                self.fd = os.open(self.path, os.O_CREAT | os.O_EXCL | os.O_WRONLY, 0o600)
                os.write(self.fd, f"{os.getpid()} {utc_now()}\n".encode())
                return self
            except FileExistsError:
                with contextlib.suppress(OSError, ValueError):
                    if utc_now() - int(self.path.stat().st_mtime) > 600:
                        self.path.unlink()
                        continue
                if time.monotonic() >= deadline:
                    raise ClusterError("服务器联动模块正被另一项操作占用")
                time.sleep(0.1)

    def __exit__(self, *_: Any) -> None:
        if self.fd is not None:
            os.close(self.fd)
        with contextlib.suppress(FileNotFoundError):
            self.path.unlink()


class Database:
    def __init__(self, path: Path):
        self.path = path
        path.parent.mkdir(parents=True, exist_ok=True)
        self._local = threading.local()

    @property
    def connection(self) -> sqlite3.Connection:
        connection = getattr(self._local, "connection", None)
        if connection is None:
            connection = sqlite3.connect(self.path, timeout=30)
            connection.row_factory = sqlite3.Row
            connection.execute("PRAGMA foreign_keys=ON")
            connection.execute("PRAGMA journal_mode=WAL")
            connection.execute("PRAGMA synchronous=FULL")
            self._local.connection = connection
        return connection

    def close(self) -> None:
        connection = getattr(self._local, "connection", None)
        if connection is not None:
            connection.close()
            self._local.connection = None

    def migrate(self) -> None:
        self.connection.executescript(
            """
            CREATE TABLE IF NOT EXISTS schema_meta(version INTEGER NOT NULL);
            INSERT INTO schema_meta(version) SELECT 1 WHERE NOT EXISTS(SELECT 1 FROM schema_meta);
            CREATE TABLE IF NOT EXISTS settings(key TEXT PRIMARY KEY,value TEXT NOT NULL);
            CREATE TABLE IF NOT EXISTS nodes(
              id TEXT PRIMARY KEY,role TEXT NOT NULL DEFAULT 'child',endpoint_host TEXT NOT NULL,
              endpoint_hosts TEXT NOT NULL DEFAULT '[]',
              endpoint_port INTEGER NOT NULL,internal_port INTEGER NOT NULL,remark TEXT NOT NULL DEFAULT '',
              server_number INTEGER NOT NULL DEFAULT 0,
              expected_uuid TEXT NOT NULL DEFAULT '',country_code TEXT NOT NULL DEFAULT 'ZZ',
              country TEXT NOT NULL DEFAULT '',region TEXT NOT NULL DEFAULT '',city TEXT NOT NULL DEFAULT '',
              provider TEXT NOT NULL DEFAULT '',location_manual INTEGER NOT NULL DEFAULT 0,
              state TEXT NOT NULL DEFAULT 'unknown',last_seen INTEGER NOT NULL DEFAULT 0,
              last_success INTEGER NOT NULL DEFAULT 0,last_failure INTEGER NOT NULL DEFAULT 0,
              snapshot_at INTEGER NOT NULL DEFAULT 0,lun_version TEXT NOT NULL DEFAULT '',
              api_version INTEGER NOT NULL DEFAULT 1,created_at INTEGER NOT NULL,updated_at INTEGER NOT NULL
            );
            CREATE TABLE IF NOT EXISTS join_tokens(
              token_hash TEXT PRIMARY KEY,expires_at INTEGER NOT NULL,used_at INTEGER NOT NULL DEFAULT 0,
              created_at INTEGER NOT NULL
            );
            CREATE TABLE IF NOT EXISTS node_number_history(
              node_id TEXT PRIMARY KEY,server_number INTEGER NOT NULL UNIQUE,allocated_at INTEGER NOT NULL
            );
            CREATE TABLE IF NOT EXISTS snapshots(
              node_id TEXT NOT NULL REFERENCES nodes(id) ON DELETE CASCADE,profile_key TEXT NOT NULL,
              filename TEXT NOT NULL,content BLOB NOT NULL,content_sha256 TEXT NOT NULL,created_at INTEGER NOT NULL,
              PRIMARY KEY(node_id,profile_key,filename)
            );
            CREATE TABLE IF NOT EXISTS profiles(
              id INTEGER PRIMARY KEY AUTOINCREMENT,name TEXT NOT NULL UNIQUE,token TEXT NOT NULL UNIQUE,
              selector TEXT NOT NULL DEFAULT 'all',enabled INTEGER NOT NULL DEFAULT 1,
              created_at INTEGER NOT NULL,updated_at INTEGER NOT NULL
            );
            CREATE TABLE IF NOT EXISTS user_nodes(
              user_id INTEGER NOT NULL,node_id TEXT NOT NULL REFERENCES nodes(id) ON DELETE CASCADE,
              created_at INTEGER NOT NULL,PRIMARY KEY(user_id,node_id)
            );
            CREATE TABLE IF NOT EXISTS usage_reports(
              node_id TEXT NOT NULL REFERENCES nodes(id) ON DELETE CASCADE,device_uuid TEXT NOT NULL,
              epoch TEXT NOT NULL,uplink INTEGER NOT NULL,downlink INTEGER NOT NULL,
              month_uplink INTEGER NOT NULL,month_downlink INTEGER NOT NULL,sequence INTEGER NOT NULL,
              reported_at INTEGER NOT NULL,PRIMARY KEY(node_id,device_uuid,epoch)
            );
            CREATE TABLE IF NOT EXISTS jobs(
              request_id TEXT PRIMARY KEY,node_id TEXT NOT NULL,action TEXT NOT NULL,status TEXT NOT NULL,
              detail TEXT NOT NULL DEFAULT '',created_at INTEGER NOT NULL,updated_at INTEGER NOT NULL
            );
            CREATE TABLE IF NOT EXISTS audit_log(
              id INTEGER PRIMARY KEY AUTOINCREMENT,created_at INTEGER NOT NULL,action TEXT NOT NULL,
              target TEXT NOT NULL,detail TEXT NOT NULL DEFAULT ''
            );
            CREATE TABLE IF NOT EXISTS federation_keys(
              node_id TEXT PRIMARY KEY,root_certificate TEXT NOT NULL,identity_certificate TEXT NOT NULL DEFAULT '',
              revoked_at INTEGER NOT NULL DEFAULT 0,created_at INTEGER NOT NULL,updated_at INTEGER NOT NULL
            );
            CREATE TABLE IF NOT EXISTS federation_events(
              event_id TEXT PRIMARY KEY,author_id TEXT NOT NULL,author_seq INTEGER NOT NULL,prev_hash TEXT NOT NULL,
              lamport INTEGER NOT NULL,type TEXT NOT NULL,entity_key TEXT NOT NULL,payload TEXT NOT NULL,
              created_at INTEGER NOT NULL,signature TEXT NOT NULL,event_hash TEXT NOT NULL,
              UNIQUE(author_id,author_seq)
            );
            CREATE INDEX IF NOT EXISTS federation_events_author_idx ON federation_events(author_id,author_seq);
            CREATE TABLE IF NOT EXISTS federation_heads(
              author_id TEXT PRIMARY KEY,author_seq INTEGER NOT NULL,event_hash TEXT NOT NULL,lamport INTEGER NOT NULL
            );
            CREATE TABLE IF NOT EXISTS federation_entities(
              entity_key TEXT PRIMARY KEY,type TEXT NOT NULL,payload TEXT NOT NULL,deleted INTEGER NOT NULL DEFAULT 0,
              lamport INTEGER NOT NULL,author_id TEXT NOT NULL,event_id TEXT NOT NULL,updated_at INTEGER NOT NULL
            );
            CREATE TABLE IF NOT EXISTS federation_failures(
              candidate_id TEXT NOT NULL,reporter_id TEXT NOT NULL,failed_at INTEGER NOT NULL,
              PRIMARY KEY(candidate_id,reporter_id,failed_at)
            );
            CREATE TABLE IF NOT EXISTS federation_probe_votes(
              candidate_id TEXT NOT NULL,voter_id TEXT NOT NULL,reachable INTEGER NOT NULL,created_at INTEGER NOT NULL,
              signature TEXT NOT NULL DEFAULT '',PRIMARY KEY(candidate_id,voter_id)
            );
            CREATE TABLE IF NOT EXISTS federation_probe_observations(
              vote_id TEXT PRIMARY KEY,candidate_id TEXT NOT NULL,voter_id TEXT NOT NULL,
              reachable INTEGER NOT NULL,observed_at INTEGER NOT NULL,nonce TEXT NOT NULL,
              signature TEXT NOT NULL,received_at INTEGER NOT NULL,UNIQUE(voter_id,nonce)
            );
            CREATE INDEX IF NOT EXISTS federation_probe_window_idx
              ON federation_probe_observations(candidate_id,observed_at,voter_id);
            CREATE TABLE IF NOT EXISTS federation_number_claims(
              node_id TEXT PRIMARY KEY,requested_number INTEGER NOT NULL,fixed INTEGER NOT NULL DEFAULT 0,
              lamport INTEGER NOT NULL,author_id TEXT NOT NULL,event_id TEXT NOT NULL,
              assigned_number INTEGER NOT NULL DEFAULT 0
            );
            CREATE TABLE IF NOT EXISTS federation_join_transactions(
              transaction_id TEXT PRIMARY KEY,direction TEXT NOT NULL,token_hash TEXT NOT NULL,
              peer_id TEXT NOT NULL,bundle_sha256 TEXT NOT NULL,transaction_signature TEXT NOT NULL,
              transaction_payload TEXT NOT NULL DEFAULT '',response_bundle TEXT NOT NULL DEFAULT '',status TEXT NOT NULL,
              created_at INTEGER NOT NULL,updated_at INTEGER NOT NULL
            );
            CREATE INDEX IF NOT EXISTS audit_created_idx ON audit_log(created_at DESC);
            UPDATE schema_meta SET version=3;
            """
        )
        node_columns = {row[1] for row in self.connection.execute("PRAGMA table_info(nodes)")}
        if "server_number" not in node_columns:
            self.connection.execute("ALTER TABLE nodes ADD COLUMN server_number INTEGER NOT NULL DEFAULT 0")
        if "endpoint_hosts" not in node_columns:
            self.connection.execute("ALTER TABLE nodes ADD COLUMN endpoint_hosts TEXT NOT NULL DEFAULT '[]'")
        key_columns = {row[1] for row in self.connection.execute("PRAGMA table_info(federation_keys)")}
        for definition in (
            "root_fingerprint TEXT NOT NULL DEFAULT ''",
            "identity_fingerprint TEXT NOT NULL DEFAULT ''",
            "revoked_after_seq INTEGER NOT NULL DEFAULT -1",
            "revocation_event_id TEXT NOT NULL DEFAULT ''",
        ):
            name = definition.split()[0]
            if name not in key_columns:
                self.connection.execute(f"ALTER TABLE federation_keys ADD COLUMN {definition}")
        transaction_columns = {
            row[1] for row in self.connection.execute("PRAGMA table_info(federation_join_transactions)")
        }
        if "transaction_payload" not in transaction_columns:
            self.connection.execute(
                "ALTER TABLE federation_join_transactions ADD COLUMN transaction_payload TEXT NOT NULL DEFAULT ''"
            )
        rows = self.connection.execute(
            "SELECT id,role,server_number,created_at FROM nodes "
            "ORDER BY CASE role WHEN 'master' THEN 0 ELSE 1 END,created_at,id"
        ).fetchall()
        used = {
            int(row[0]) for row in self.connection.execute(
                "SELECT server_number FROM node_number_history WHERE server_number>0"
            )
        }
        for row in rows:
            existing = self.connection.execute(
                "SELECT server_number FROM node_number_history WHERE node_id=?", (row["id"],)
            ).fetchone()
            number = int(existing[0]) if existing else int(row["server_number"] or 0)
            if number < 1 or (number in used and not existing):
                number = 1
                while number in used:
                    number += 1
            self.connection.execute(
                "INSERT INTO node_number_history(node_id,server_number,allocated_at) VALUES(?,?,?) "
                "ON CONFLICT(node_id) DO NOTHING",
                (row["id"], number, int(row["created_at"] or utc_now())),
            )
            self.connection.execute("UPDATE nodes SET server_number=? WHERE id=?", (number, row["id"]))
            used.add(number)
        profile_columns = {row[1] for row in self.connection.execute("PRAGMA table_info(profiles)")}
        if "profile_key" not in profile_columns:
            self.connection.execute("ALTER TABLE profiles ADD COLUMN profile_key TEXT NOT NULL DEFAULT 'legacy'")
        self.connection.commit()

    def setting(self, key: str, default: str = "") -> str:
        row = self.connection.execute("SELECT value FROM settings WHERE key=?", (key,)).fetchone()
        return row[0] if row else default

    def set_setting(self, key: str, value: Any) -> None:
        with self.connection:
            self.connection.execute(
                "INSERT INTO settings(key,value) VALUES(?,?) ON CONFLICT(key) DO UPDATE SET value=excluded.value",
                (key, str(value)),
            )

    def audit(self, action: str, target: str, detail: str = "") -> None:
        with self.connection:
            self.connection.execute(
                "INSERT INTO audit_log(created_at,action,target,detail) VALUES(?,?,?,?)",
                (utc_now(), action, target, safe_label(detail, 500)),
            )


class Cluster:
    def __init__(self, root: Path):
        self.root = root
        self.module = root / "modules" / "cluster"
        self.data = self.module / "data"
        self.pki = self.module / "pki"
        self.cache = self.module / "generated"
        self.backups = self.module / "backups"
        self.config_path = self.module / "config.json"
        self.lock_path = self.module / ".lock"
        self.db = Database(self.data / "cluster.db")
        self.db.migrate()
        self.reconcile_local_identity()

    def close(self) -> None:
        self.db.close()

    def replace_database(self, source: Path) -> None:
        """Replace database contents through SQLite's online backup API.

        The cluster server is threaded. Replacing cluster.db with shutil.copy2
        leaves other threads holding connections to the old inode and can make
        their WAL writes corrupt the new file. SQLite backup coordinates all
        active connections and keeps the destination inode stable.
        """
        if not source.is_file():
            raise ClusterError("集群数据库恢复文件不存在")
        candidate = sqlite3.connect(f"file:{source.resolve().as_posix()}?mode=ro", uri=True)
        try:
            if candidate.execute("PRAGMA integrity_check").fetchone()[0] != "ok":
                raise ClusterError("集群数据库恢复文件完整性检查失败")
            candidate.backup(self.db.connection)
        finally:
            candidate.close()
        if self.db.connection.execute("PRAGMA integrity_check").fetchone()[0] != "ok":
            raise ClusterError("集群数据库替换后完整性检查失败")
        self.db.migrate()

    def load_config(self) -> dict[str, Any]:
        if not self.config_path.exists():
            return {"enabled": False, "role": "disabled", "api_version": API_VERSION}
        try:
            return json.loads(self.config_path.read_text(encoding="utf-8"))
        except (OSError, json.JSONDecodeError) as exc:
            raise ClusterError(f"集群配置无法读取：{exc}") from exc

    def save_config(self, config: dict[str, Any]) -> None:
        config["api_version"] = API_VERSION
        config["updated_at"] = utc_now()
        atomic_write(self.config_path, json.dumps(config, ensure_ascii=False, indent=2) + "\n")
        self.secure_files()

    def secure_files(self) -> None:
        for directory in (self.module, self.data, self.pki, self.cache, self.backups):
            directory.mkdir(parents=True, exist_ok=True)
            with contextlib.suppress(OSError):
                os.chmod(directory, 0o700)
        for path in (self.config_path, self.db.path):
            if path.exists():
                with contextlib.suppress(OSError):
                    os.chmod(path, 0o600)
        for path in self.pki.glob("*"):
            with contextlib.suppress(OSError):
                os.chmod(path, 0o600 if path.suffix in {".key", ".csr"} else 0o644)

    def allocate_server_number(self, node_id: str, preferred: int = 0) -> int:
        row = self.db.connection.execute(
            "SELECT server_number FROM node_number_history WHERE node_id=?", (node_id,)
        ).fetchone()
        if row:
            return int(row[0])
        used = {
            int(item[0]) for item in self.db.connection.execute(
                "SELECT server_number FROM node_number_history WHERE server_number>0"
            )
        }
        number = int(preferred or 0)
        if number < 1 or number in used:
            number = 1
            while number in used:
                number += 1
        with self.db.connection:
            self.db.connection.execute(
                "INSERT INTO node_number_history(node_id,server_number,allocated_at) VALUES(?,?,?)",
                (node_id, number, utc_now()),
            )
        return number

    def place_labels(self) -> dict[str, str]:
        rows = self.db.connection.execute(
            "SELECT * FROM nodes WHERE state NOT IN ('revoked','removed') ORDER BY server_number,id"
        ).fetchall()
        return numbered_place_labels(rows)

    def identity_place(self, row: sqlite3.Row | dict[str, Any]) -> str:
        base = chinese_place(dict(row))
        return self.place_labels().get(str(row.get("id", "") if isinstance(row, dict) else row["id"]), base)

    def identity_signature(self, row: sqlite3.Row | dict[str, Any]) -> str:
        payload = {
            "server_number": int(row["server_number"]),
            "place": self.identity_place(row),
            "location": {key: str(row[key] or "") for key in (
                "country_code", "country", "region", "city", "provider"
            )},
        }
        return hashlib.sha256(json_dumps(payload).encode("utf-8")).hexdigest()

    def mark_identity_synced(self, row: sqlite3.Row | dict[str, Any]) -> None:
        self.db.set_setting(f"identity-synced:{row['id']}", self.identity_signature(row))

    def identity_sync_pending(self, row: sqlite3.Row | dict[str, Any]) -> bool:
        return self.db.setting(f"identity-synced:{row['id']}") != self.identity_signature(row)

    @staticmethod
    def normalize_identity_location(location: dict[str, Any] | None, place: str = "") -> dict[str, str]:
        source = location if isinstance(location, dict) else {}
        place = safe_label(place or str(source.get("region", "")))
        country_code = normalize_country_code(str(source.get("country_code", "")))
        if country_code == "ZZ":
            country_code = infer_country_code(place)
        return {
            "country_code": country_code,
            "country": safe_label(str(source.get("country", ""))) or COUNTRY_NAMES_ZH.get(country_code, ""),
            "region": place or safe_label(str(source.get("region", ""))),
            "city": safe_label(str(source.get("city", ""))),
            "provider": safe_label(str(source.get("provider", ""))),
        }

    def apply_local_identity(self, server_number: int, location: dict[str, Any] | None,
                             place_override: str = "") -> dict[str, Any]:
        number = int(server_number)
        if number < 1:
            raise ClusterError("服务器编号必须大于 0")
        normalized = self.normalize_identity_location(location)
        place = canonical_place_label(safe_label(place_override, 48)) or chinese_place(normalized)
        number_text = f"{number:02d}" if number < 100 else str(number)
        atomic_write(self.root / "server_number", number_text + "\n")
        atomic_write(self.root / "server_place", place + "\n")
        config = self.load_config()
        if config.get("enabled"):
            config["server_number"] = number
            config["location"] = normalized
            config["place"] = place
            self.save_config(config)
        return {"server_number": number, "location": normalized, "place": place}

    def rebuild_identity_subscriptions(self) -> None:
        script = Path(os.environ.get("LUN_SCRIPT", "/usr/bin/lun"))
        if not script.exists():
            return
        result = self._run(["bash", str(script), "cluster-refresh-identity"], timeout=300, check=False)
        if result.returncode:
            raise ClusterError((result.stderr or result.stdout or "节点名称订阅重建失败")[-2000:])

    def apply_identity_transaction(self, server_number: int, location: dict[str, Any] | None,
                                   place_override: str = "") -> dict[str, Any]:
        config = self.load_config()
        old_number = int(config.get("server_number", 1))
        old_location = config.get("location") if isinstance(config.get("location"), dict) else {}
        old_place = safe_label(str(config.get("place", "")), 48)
        try:
            identity = self.apply_local_identity(server_number, location, place_override)
            self.rebuild_identity_subscriptions()
            return identity
        except Exception:
            with contextlib.suppress(Exception):
                self.apply_local_identity(old_number, old_location, old_place)
                self.rebuild_identity_subscriptions()
            raise

    def reconcile_local_identity(self) -> None:
        if not self.config_path.exists():
            return
        with contextlib.suppress(ClusterError, OSError, ValueError, sqlite3.Error):
            number_path = self.root / "server_number"
            place_path = self.root / "server_place"
            previous_number = number_path.read_text(encoding="utf-8").strip() if number_path.exists() else ""
            previous_place = place_path.read_text(encoding="utf-8").strip() if place_path.exists() else ""
            config = self.load_config()
            node_id = str(config.get("node_id", ""))
            row = self.db.connection.execute("SELECT * FROM nodes WHERE id=?", (node_id,)).fetchone()
            if row:
                location = {key: row[key] for key in ("country_code", "country", "region", "city", "provider")}
                identity = self.apply_local_identity(
                    int(row["server_number"]), location, self.identity_place(row)
                )
            else:
                number_text = previous_number or str(config.get("server_number", 1))
                identity = self.apply_local_identity(
                    int(number_text or 1), self.normalize_identity_location(config.get("location"), previous_place),
                    safe_label(str(config.get("place", "")), 48) or previous_place,
                )
            number_text = f"{identity['server_number']:02d}" if identity["server_number"] < 100 else str(identity["server_number"])
            if previous_number != number_text or previous_place != identity["place"]:
                self.rebuild_identity_subscriptions()

    def _run(self, command: list[str], *, input_text: str | None = None, timeout: int = 60,
             env: dict[str, str] | None = None, check: bool = True) -> subprocess.CompletedProcess[str]:
        result = subprocess.run(
            command, input=input_text, text=True, capture_output=True, timeout=timeout,
            env=env, check=False,
        )
        if check and result.returncode:
            message = (result.stderr or result.stdout or "命令失败").strip()[-2000:]
            raise ClusterError(message)
        return result

    def _openssl(self, arguments: list[str], timeout: int = 60, check: bool = True) -> subprocess.CompletedProcess[str]:
        executable = shutil.which("openssl")
        if not executable:
            raise ClusterError("服务器联动需要 OpenSSL")
        return self._run([executable, *arguments], timeout=timeout, check=check)

    def _create_key_and_csr(self, name: str, common_name: str | None = None) -> tuple[Path, Path]:
        self.pki.mkdir(parents=True, exist_ok=True)
        key = self.pki / f"{name}.key"
        csr = self.pki / f"{name}.csr"
        common_name = common_name or name
        if not re.fullmatch(r"[0-9A-Za-z ._-]{1,80}", common_name):
            raise ClusterError("证书身份无效")
        self._openssl(["ecparam", "-genkey", "-name", "prime256v1", "-out", str(key)])
        self._openssl(["req", "-new", "-key", str(key), "-out", str(csr), "-subj", f"/CN={common_name}"])
        return key, csr

    def _create_ca(self, cluster_id: str) -> None:
        self.pki.mkdir(parents=True, exist_ok=True)
        key = self.pki / "cluster-ca.key"
        cert = self.pki / "cluster-ca.crt"
        self._openssl(["ecparam", "-genkey", "-name", "prime256v1", "-out", str(key)])
        self._openssl([
            "req", "-new", "-x509", "-sha256", "-days", "3650", "-key", str(key),
            "-out", str(cert), "-subj", f"/CN=Lun Cluster {cluster_id}",
        ])

    def _sign_csr(self, csr_pem: str, node_id: str, output: Path) -> str:
        if not re.fullmatch(r"[0-9a-f]{32}", node_id):
            raise ClusterError("节点 ID 无效")
        with tempfile.TemporaryDirectory(dir=self.module) as temporary:
            csr = Path(temporary) / "node.csr"
            ext = Path(temporary) / "node.ext"
            csr.write_text(csr_pem, encoding="utf-8")
            subject = self._openssl(["req", "-in", str(csr), "-noout", "-subject"]).stdout
            normalized_subject = re.sub(r"\s+", "", subject)
            if not (normalized_subject.endswith(f"CN={node_id}") or f"/CN={node_id}" in normalized_subject):
                raise ClusterError("子 VPS CSR 身份与加入地址不一致")
            ext.write_text(
                "basicConstraints=critical,CA:FALSE\n"
                "keyUsage=critical,digitalSignature,keyEncipherment\n"
                "extendedKeyUsage=serverAuth,clientAuth\n"
                f"subjectAltName=URI:lun-node:{node_id}\n",
                encoding="ascii",
            )
            self._openssl([
                "x509", "-req", "-in", str(csr), "-CA", str(self.pki / "cluster-ca.crt"),
                "-CAkey", str(self.pki / "cluster-ca.key"), "-CAcreateserial", "-out", str(output),
                "-days", "365", "-sha256", "-extfile", str(ext),
            ])
        return output.read_text(encoding="utf-8")

    def _create_bootstrap_certificate(self, node_id: str) -> None:
        key, _ = self._create_key_and_csr("node", node_id)
        cert = self.pki / "node.crt"
        self._openssl([
            "req", "-new", "-x509", "-sha256", "-days", "30", "-key", str(key),
            "-out", str(cert), "-subj", f"/CN={node_id}",
        ])

    def certificate_fingerprint(self, certificate: Path | None = None) -> str:
        serving = self.pki / "node-serving.crt"
        cert = certificate or (self.pki / "federation-node.crt" if self.is_federation() else (serving if serving.is_file() else self.pki / "node.crt"))
        result = self._openssl(["x509", "-in", str(cert), "-noout", "-fingerprint", "-sha256"])
        value = result.stdout.strip().split("=", 1)[-1].replace(":", "").lower()
        if not re.fullmatch(r"[0-9a-f]{64}", value):
            raise ClusterError("无法计算集群证书指纹")
        return value

    def init_master(self, public_host: str, internal_port: int, public_port: int | None = None,
                    remark: str = "") -> dict[str, Any]:
        if not valid_port(internal_port) or not valid_port(public_port or internal_port):
            raise ClusterError("通信端口必须在 1-65535")
        host = normalize_host(public_host)
        node_id = random_node_id()
        cluster_id = uuid.uuid4().hex
        server_number = self.allocate_server_number(node_id, 1)
        place = (self.root / "server_place").read_text(encoding="utf-8").strip() \
            if (self.root / "server_place").exists() else ""
        location = self.normalize_identity_location({}, place)
        self._create_ca(cluster_id)
        _, csr = self._create_key_and_csr("node", node_id)
        self._sign_csr(csr.read_text(encoding="utf-8"), node_id, self.pki / "node.crt")
        config = {
            "enabled": True, "role": "master", "cluster_id": cluster_id, "node_id": node_id,
            "bind": "0.0.0.0", "public_host": host, "internal_port": int(internal_port),
            "public_port": int(public_port or internal_port), "remark": safe_label(remark),
            "server_number": server_number, "location": location,
            "paired": True, "created_at": utc_now(),
        }
        self.save_config(config)
        self.apply_local_identity(server_number, location)
        self.upsert_node(self.local_snapshot()["status"], role="master")
        self.ensure_profile("全部节点", "all")
        self.record_local_snapshot()
        self.db.audit("cluster.init-master", node_id, f"{host}:{config['public_port']}")
        return config

    def init_child(self, public_host: str, internal_port: int, public_port: int | None = None,
                   remark: str = "") -> dict[str, Any]:
        if not valid_port(internal_port) or not valid_port(public_port or internal_port):
            raise ClusterError("通信端口必须在 1-65535")
        host = normalize_host(public_host)
        node_id = random_node_id()
        number_path = self.root / "server_number"
        place_path = self.root / "server_place"
        number = int(number_path.read_text(encoding="utf-8").strip() or 1) if number_path.exists() else 1
        place = place_path.read_text(encoding="utf-8").strip() if place_path.exists() else ""
        location = self.normalize_identity_location({}, place)
        self._create_bootstrap_certificate(node_id)
        config = {
            "enabled": True, "role": "child", "cluster_id": "", "node_id": node_id,
            "bind": "0.0.0.0", "public_host": host, "internal_port": int(internal_port),
            "public_port": int(public_port or internal_port), "remark": safe_label(remark),
            "server_number": number, "location": location,
            "paired": False, "created_at": utc_now(),
        }
        self.save_config(config)
        self.apply_local_identity(number, location)
        self.db.audit("cluster.init-child", node_id, f"{host}:{config['public_port']}")
        return {**config, "join_uri": self.create_join_code()}

    def create_join_code(self) -> str:
        config = self.load_config()
        if config.get("role") != "child" and not self.is_federation():
            raise ClusterError("只有子 VPS 可以生成加入地址")
        token = b64url(secrets.token_bytes(32))
        expires = utc_now() + JOIN_TTL
        token_hash = hashlib.sha256(token.encode()).hexdigest()
        with self.db.connection:
            self.db.connection.execute("DELETE FROM join_tokens WHERE used_at=0 OR expires_at<?", (utc_now(),))
            self.db.connection.execute(
                "INSERT INTO join_tokens(token_hash,expires_at,created_at) VALUES(?,?,?)",
                (token_hash, expires, utc_now()),
            )
        return make_join_uri(
            config["public_host"], int(config["public_port"]), config["node_id"], token,
            self.certificate_fingerprint(), expires,
        )

    def consume_join_token(self, token: str) -> None:
        digest = hashlib.sha256(token.encode()).hexdigest()
        row = self.db.connection.execute(
            "SELECT * FROM join_tokens WHERE token_hash=?", (digest,)
        ).fetchone()
        if not row or row["used_at"] or row["expires_at"] < utc_now():
            raise ClusterError("一次性加入令牌无效、已使用或已过期")
        with self.db.connection:
            self.db.connection.execute("UPDATE join_tokens SET used_at=? WHERE token_hash=?", (utc_now(), digest))

    def upsert_node(self, status: dict[str, Any], *, role: str = "child", remark: str | None = None,
                    expected_uuid: str | None = None) -> None:
        node_id = status.get("node_id", "")
        if not re.fullmatch(r"[0-9a-f]{32}", node_id):
            raise ClusterError("节点状态缺少有效 node_id")
        host = normalize_host(status.get("public_host", ""))
        raw_hosts = status.get("public_hosts") if isinstance(status.get("public_hosts"), list) else []
        hosts = order_public_hosts(raw_hosts, host)
        host = hosts[0] if hosts else host
        port = int(status.get("public_port", 0))
        internal = int(status.get("internal_port", port))
        if not valid_port(port) or not valid_port(internal):
            raise ClusterError("节点状态中的端口无效")
        now = utc_now()
        existing = self.db.connection.execute("SELECT * FROM nodes WHERE id=?", (node_id,)).fetchone()
        server_number = self.allocate_server_number(node_id, 1 if role == "master" else 0)
        location = status.get("location") if isinstance(status.get("location"), dict) else {}
        values = {
            "remark": safe_label(remark if remark is not None else (existing["remark"] if existing else status.get("remark", ""))),
            "expected_uuid": safe_label(expected_uuid if expected_uuid is not None else (existing["expected_uuid"] if existing else ""), 64),
            "country_code": normalize_country_code(location.get("country_code", existing["country_code"] if existing else "ZZ")),
            "country": safe_label(location.get("country", existing["country"] if existing else "")),
            "region": safe_label(location.get("region", existing["region"] if existing else "")),
            "city": safe_label(location.get("city", existing["city"] if existing else "")),
            "provider": safe_label(location.get("provider", existing["provider"] if existing else "")),
        }
        with self.db.connection:
            self.db.connection.execute(
                """INSERT INTO nodes(
                id,role,endpoint_host,endpoint_hosts,endpoint_port,internal_port,remark,server_number,expected_uuid,country_code,
                country,region,city,provider,state,last_seen,last_success,snapshot_at,lun_version,
                api_version,created_at,updated_at) VALUES(?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)
                ON CONFLICT(id) DO UPDATE SET role=excluded.role,endpoint_host=excluded.endpoint_host,
                endpoint_hosts=excluded.endpoint_hosts,
                endpoint_port=excluded.endpoint_port,internal_port=excluded.internal_port,
                remark=excluded.remark,server_number=excluded.server_number,expected_uuid=excluded.expected_uuid,
                country_code=CASE WHEN nodes.location_manual=1 THEN nodes.country_code ELSE excluded.country_code END,
                country=CASE WHEN nodes.location_manual=1 THEN nodes.country ELSE excluded.country END,
                region=CASE WHEN nodes.location_manual=1 THEN nodes.region ELSE excluded.region END,
                city=CASE WHEN nodes.location_manual=1 THEN nodes.city ELSE excluded.city END,
                provider=CASE WHEN nodes.location_manual=1 THEN nodes.provider ELSE excluded.provider END,
                state='online',last_seen=excluded.last_seen,last_success=excluded.last_success,
                lun_version=excluded.lun_version,api_version=excluded.api_version,updated_at=excluded.updated_at""",
                (
                    node_id, role, host, json_dumps(hosts), port, internal, values["remark"], server_number, values["expected_uuid"],
                    values["country_code"], values["country"], values["region"], values["city"],
                    values["provider"], "online", now, now, int(status.get("snapshot_at", 0)),
                    safe_label(status.get("lun_version", ""), 32), int(status.get("api_version", API_VERSION)),
                    now, now,
                ),
            )

    def set_location(self, node_id: str, country_code: str, country: str = "", region: str = "",
                     city: str = "", provider: str = "", manual: bool = True) -> None:
        with self.db.connection:
            result = self.db.connection.execute(
                "UPDATE nodes SET country_code=?,country=?,region=?,city=?,provider=?,location_manual=?,updated_at=? WHERE id=?",
                (normalize_country_code(country_code), safe_label(country), safe_label(region), safe_label(city),
                 safe_label(provider), int(manual), utc_now(), node_id),
            )
        if not result.rowcount:
            raise ClusterError("节点不存在")
        self.db.audit("node.location", node_id, f"{country_code}/{region}/{city}")

    def geolocate(self, node_id: str, timeout: int = 8) -> dict[str, str]:
        row = self.node(node_id)
        if row["location_manual"]:
            return {key: row[key] for key in ("country_code", "country", "region", "city", "provider")}
        host = row["endpoint_host"]
        try:
            ipaddress.ip_address(host)
        except ValueError:
            addresses = socket.getaddrinfo(host, None, type=socket.SOCK_STREAM)
            if not addresses:
                raise ClusterError("无法解析节点公网地址")
            host = addresses[0][4][0]
        url = "https://ipwho.is/" + urllib.parse.quote(host, safe=":")
        request = urllib.request.Request(url, headers={"User-Agent": f"FHLUN-Cluster/{VERSION}"})
        try:
            with urllib.request.urlopen(request, timeout=timeout) as response:
                payload = json.loads(response.read(256 * 1024).decode("utf-8"))
        except (OSError, ValueError, json.JSONDecodeError) as exc:
            raise ClusterError(f"自动地区识别失败：{exc}") from exc
        if not payload.get("success"):
            raise ClusterError("自动地区识别服务未返回有效位置")
        connection = payload.get("connection") if isinstance(payload.get("connection"), dict) else {}
        location = {
            "country_code": normalize_country_code(payload.get("country_code", "")),
            "country": safe_label(payload.get("country", "")),
            "region": safe_label(payload.get("region", "")),
            "city": safe_label(payload.get("city", "")),
            "provider": safe_label(connection.get("isp") or connection.get("org") or ""),
        }
        self.set_location(node_id, **location, manual=False)
        return location

    def node(self, node_id: str) -> sqlite3.Row:
        node_id = node_id.strip().lower()
        if re.fullmatch(r"0*[1-9][0-9]{0,3}", node_id):
            row = self.db.connection.execute(
                "SELECT * FROM nodes WHERE server_number=?", (int(node_id),)
            ).fetchone()
        elif re.fullmatch(r"[0-9a-f]{8,31}", node_id):
            rows = self.db.connection.execute(
                "SELECT * FROM nodes WHERE id LIKE ? ORDER BY id", (node_id + "%",)
            ).fetchall()
            if len(rows) > 1:
                raise ClusterError("节点短 ID 不唯一，请输入更多字符")
            row = rows[0] if rows else None
        else:
            row = self.db.connection.execute("SELECT * FROM nodes WHERE id=?", (node_id,)).fetchone()
        if not row:
            raise ClusterError("节点不存在")
        return row

    def nodes(self) -> list[dict[str, Any]]:
        config = self.load_config()
        if config.get("role") == "master" and re.fullmatch(r"[0-9a-f]{32}", str(config.get("node_id", ""))):
            self.upsert_node(self.local_status(), role="master")
        rows = self.db.connection.execute(
            "SELECT * FROM nodes WHERE state NOT IN ('revoked','removed') ORDER BY server_number,id"
        ).fetchall()
        trusted: set[str] = set()
        if self.is_federation():
            trusted = {str(row[0]) for row in self.db.connection.execute(
                "SELECT n.id FROM nodes n JOIN federation_keys k ON k.node_id=n.id "
                "WHERE k.revoked_at=0 AND n.state NOT IN ('legacy-unverified','revoked','removed')"
            )}
        result: list[dict[str, Any]] = []
        for row in rows:
            item = dict(row)
            try:
                stored_hosts = json.loads(str(item.get("endpoint_hosts") or "[]"))
            except json.JSONDecodeError:
                stored_hosts = []
            item["endpoint_hosts"] = order_public_hosts(
                stored_hosts if isinstance(stored_hosts, list) else [], item.get("endpoint_host", "")
            )
            item["number"] = int(row["server_number"])
            if self.is_federation():
                item["trusted"] = str(row["id"]) in trusted
            result.append(item)
        return result

    def trusted_federation_nodes(self, *, include_self: bool = False) -> list[sqlite3.Row]:
        if not self.is_federation():
            return []
        local_id = str(self.load_config().get("node_id", ""))
        rows = self.db.connection.execute(
            "SELECT n.* FROM nodes n JOIN federation_keys k ON k.node_id=n.id "
            "WHERE k.revoked_at=0 AND n.state NOT IN ('legacy-unverified','revoked','removed') "
            "ORDER BY n.server_number,n.id"
        ).fetchall()
        return [row for row in rows if include_self or str(row["id"]) != local_id]

    def reconcile_repaired_legacy_member(self, node_id: str) -> list[str]:
        """Remove only untrusted migration placeholders for the same physical endpoint."""
        target = self.node(node_id)
        stale = self.db.connection.execute(
            "SELECT n.id FROM nodes n LEFT JOIN federation_keys k ON k.node_id=n.id "
            "WHERE n.id<>? AND n.state='legacy-unverified' AND n.endpoint_host=? AND k.node_id IS NULL",
            (target["id"], target["endpoint_host"]),
        ).fetchall()
        stale_ids = [str(row["id"]) for row in stale]
        if not stale_ids:
            return []
        with self.db.connection:
            for stale_id in stale_ids:
                self.db.connection.execute("DELETE FROM nodes WHERE id=?", (stale_id,))
                self.db.connection.execute("DELETE FROM node_number_history WHERE node_id=?", (stale_id,))
        self._resolve_federation_numbers()
        self.db.audit("federation.legacy-placeholder-replaced", str(target["id"]), ",".join(stale_ids))
        return stale_ids

    @staticmethod
    def normalize_cdn_pool(value: str) -> list[str]:
        if not isinstance(value, str) or not value.strip():
            raise ClusterError("CDN 优选池不能为空")
        if len(value.encode("utf-8")) > CDN_POOL_MAX_TEXT:
            raise ClusterError("CDN 优选池总长度超过限制")
        if "://" in value or any(character in value for character in "/\\?#@`$|<>"):
            raise ClusterError("CDN 优选池包含 URL、路径或危险字符")
        if any(ord(character) < 32 and character not in "\r\n\t" for character in value):
            raise ClusterError("CDN 优选池包含控制字符")
        tokens = [item for item in re.split(r"[\s,;]+", value.strip()) if item]
        if not tokens or len(tokens) > CDN_POOL_MAX_ENTRIES:
            raise ClusterError("CDN 优选池数量无效")
        result: list[str] = []
        for token in tokens:
            if len(token.encode("utf-8")) > 253 or any(character in token for character in "'\"(){}[]!*=&%"):
                raise ClusterError(f"CDN 优选地址无效：{token[:80]}")
            try:
                normalized = ipaddress.ip_address(token).compressed.lower()
            except ValueError:
                try:
                    normalized = token.rstrip(".").encode("idna").decode("ascii").lower()
                except UnicodeError as exc:
                    raise ClusterError(f"CDN 优选域名无效：{token[:80]}") from exc
                labels = normalized.split(".")
                if len(normalized) > 253 or len(labels) < 2 or any(
                    not re.fullmatch(r"[a-z0-9](?:[a-z0-9-]{0,61}[a-z0-9])?", label)
                    for label in labels
                ):
                    raise ClusterError(f"CDN 优选域名无效：{token[:80]}")
            if normalized not in result:
                result.append(normalized)
        if not result:
            raise ClusterError("CDN 优选池不能为空")
        return result

    def _cdn_pool_numbered_paths(self) -> list[Path]:
        return sorted(
            (path for path in self.root.glob("cdnip[0-9]*") if re.fullmatch(r"cdnip[1-9][0-9]*", path.name)),
            key=lambda path: int(path.name[5:]),
        )

    def read_cdn_pool(self) -> list[str]:
        primary = self.root / "cdnip"
        paths = [primary] if primary.is_file() and primary.stat().st_size else self._cdn_pool_numbered_paths()
        values: list[str] = []
        for path in paths:
            if path.stat().st_size > CDN_POOL_MAX_TEXT:
                raise ClusterError(f"CDN 优选池文件过大：{path.name}")
            text = path.read_text(encoding="utf-8")
            if not text.strip():
                continue
            for item in self.normalize_cdn_pool(text):
                if item not in values:
                    values.append(item)
        return values

    def preview_cdn_pool(self, mode: str, cfip: str) -> dict[str, Any]:
        if mode not in {"merge", "replace"}:
            raise ClusterError("CDN 优选池模式只支持 merge 或 replace")
        source = self.normalize_cdn_pool(cfip)
        current = self.read_cdn_pool()
        result = source + [item for item in current if mode == "merge" and item not in source]
        return {
            "mode": mode, "current": current, "source": source, "result": result,
            "add": [item for item in result if item not in current],
            "keep": [item for item in result if item in current],
            "remove": [item for item in current if item not in result],
        }

    def _capture_cdn_pool(self) -> dict[str, Any]:
        paths = [self.root / "cdnip", *self._cdn_pool_numbered_paths()]
        files: dict[str, dict[str, Any]] = {}
        for path in paths:
            if path.is_file():
                files[path.name] = {
                    "content": base64.b64encode(path.read_bytes()).decode("ascii"),
                    "mode": path.stat().st_mode & 0o777,
                }
        return {"created_at": utc_now(), "files": files}

    def _restore_cdn_pool(self, snapshot: dict[str, Any]) -> None:
        for path in [self.root / "cdnip", *self._cdn_pool_numbered_paths()]:
            path.unlink(missing_ok=True)
        files = snapshot.get("files") if isinstance(snapshot.get("files"), dict) else {}
        for name, item in files.items():
            if name != "cdnip" and not re.fullmatch(r"cdnip[1-9][0-9]*", str(name)):
                raise ClusterError("CDN 优选池快照包含非法文件")
            if not isinstance(item, dict):
                raise ClusterError("CDN 优选池快照无效")
            try:
                content = base64.b64decode(str(item.get("content", "")), validate=True)
            except (ValueError, binascii.Error) as exc:
                raise ClusterError("CDN 优选池快照编码无效") from exc
            atomic_write(self.root / str(name), content, int(item.get("mode", 0o600)) & 0o777)

    def _write_cdn_pool(self, values: list[str]) -> None:
        atomic_write(self.root / "cdnip", " ".join(values) + "\n", 0o600)
        for index, value in enumerate(values, 1):
            atomic_write(self.root / f"cdnip{index}", value + "\n", 0o600)
        for path in self._cdn_pool_numbered_paths():
            if int(path.name[5:]) > len(values):
                path.unlink(missing_ok=True)

    def apply_cdn_pool(self, mode: str, cfip: str, script: Path) -> dict[str, Any]:
        preview = self.preview_cdn_pool(mode, cfip)
        if not script.is_file():
            raise ClusterError("没有找到可执行的 Lun 主脚本")
        snapshot = self._capture_cdn_pool()
        self.backups.mkdir(parents=True, exist_ok=True)
        snapshot_path = self.backups / f"cdn-pool-{utc_now()}-{secrets.token_hex(4)}.json"
        atomic_write(snapshot_path, json.dumps(snapshot, ensure_ascii=False, indent=2) + "\n", 0o600)
        self._write_cdn_pool(preview["result"])
        refreshed = self._run(["bash", str(script), "subscription-refresh"], timeout=300, check=False)
        if refreshed.returncode:
            self._restore_cdn_pool(snapshot)
            rollback_refresh = self._run(["bash", str(script), "subscription-refresh"], timeout=300, check=False)
            rollback = {"restored": True, "refresh_returncode": rollback_refresh.returncode}
            self.db.audit("cdn.pool.rollback", str(self.load_config().get("node_id", "")), json_dumps(rollback))
            return {**preview, "applied": False, "snapshot": str(snapshot_path), "rollback": rollback,
                    "error": ((refreshed.stderr or refreshed.stdout or "订阅重建失败")[-2000:])}
        published: dict[str, Any] = {}
        if self.is_federation():
            with contextlib.suppress(ClusterError, OSError, sqlite3.Error):
                published = push_snapshot(self)
        else:
            self.record_local_snapshot()
        self.db.audit("cdn.pool.apply", str(self.load_config().get("node_id", "")), json_dumps(preview["result"]))
        return {**preview, "applied": True, "snapshot": str(snapshot_path), "rollback": None,
                "published": published}

    def remove_node(self, node_id: str) -> None:
        config = self.load_config()
        if config.get("role") != "master":
            raise ClusterError("只有主 VPS 可以移除子 VPS")
        row = self.node(node_id)
        if row["role"] != "child":
            raise ClusterError("不能移除主 VPS 自身")
        with self.db.connection:
            self.db.connection.execute("DELETE FROM nodes WHERE id=?", (row["id"],))
        (self.pki / f"issued-{row['id']}.crt").unlink(missing_ok=True)
        self.db.audit("node.remove", row["id"], row["remark"])

    def _lun_version(self) -> str:
        for path in (Path("/usr/bin/lun"), self.root / "lun.sh"):
            if path.exists():
                with contextlib.suppress(OSError):
                    match = re.search(r"当前版本：?(V[0-9.]+)", path.read_text(encoding="utf-8", errors="ignore"))
                    if match:
                        return match.group(1)
        return ""

    def local_status(self) -> dict[str, Any]:
        config = self.load_config()
        location = config.get("location", {}) if isinstance(config.get("location"), dict) else {}
        number_path = self.root / "server_number"
        server_number = int(number_path.read_text(encoding="utf-8").strip() or 1) \
            if number_path.exists() else int(config.get("server_number", 1))
        if not location and (self.root / "server_place").exists():
            location = self.normalize_identity_location(
                {}, (self.root / "server_place").read_text(encoding="utf-8").strip()
            )
        return {
            "node_id": config.get("node_id", ""), "cluster_id": config.get("cluster_id", ""),
            "role": config.get("role", "disabled"), "public_host": config.get("public_host", ""),
            "public_hosts": order_public_hosts(
                config.get("public_hosts", []) if isinstance(config.get("public_hosts"), list) else [],
                str(config.get("public_host", "")),
            ),
            "public_port": int(config.get("public_port", 0)),
            "internal_port": int(config.get("internal_port", 0)), "remark": config.get("remark", ""),
            "paired": bool(config.get("paired")), "api_version": API_VERSION,
            "lun_version": self._lun_version(), "snapshot_at": utc_now(), "location": location,
            "server_number": server_number,
            "uuid": (self.root / "uuid").read_text(encoding="utf-8").strip() if (self.root / "uuid").exists() else "",
        }

    def local_snapshot(self, profile_key: str = "legacy") -> dict[str, Any]:
        files: dict[str, str] = {}
        profile_key = safe_slug(profile_key)
        for filename in SUBSCRIPTION_FILES:
            candidate = self.root / "modules" / "multiuser" / "generated" / profile_key / filename
            path = candidate if profile_key != "legacy" and candidate.exists() else self.root / filename
            if path.exists():
                files[filename] = base64.b64encode(path.read_bytes()).decode()
        return {"status": self.local_status(), "profile_key": profile_key, "files": files}

    def record_snapshot(self, payload: dict[str, Any], role: str = "child") -> None:
        status = payload.get("status") if isinstance(payload.get("status"), dict) else {}
        profile_key = safe_slug(str(payload.get("profile_key", "legacy")))
        self.upsert_node(status, role=role)
        node_id = status["node_id"]
        files = payload.get("files") if isinstance(payload.get("files"), dict) else {}
        now = utc_now()
        with self.db.connection:
            for filename, encoded in files.items():
                if filename not in SUBSCRIPTION_FILES or not isinstance(encoded, str):
                    continue
                try:
                    content = b64decode(encoded)
                except (ValueError, binascii.Error):
                    raise ClusterError(f"节点 {short_id(node_id)} 的订阅快照编码无效")
                if len(content) > MAX_BODY:
                    raise ClusterError("单个订阅快照超过大小限制")
                self.db.connection.execute(
                    """INSERT INTO snapshots(node_id,profile_key,filename,content,content_sha256,created_at)
                    VALUES(?,?,?,?,?,?) ON CONFLICT(node_id,profile_key,filename) DO UPDATE SET
                    content=excluded.content,content_sha256=excluded.content_sha256,created_at=excluded.created_at""",
                    (node_id, profile_key, filename, content, hashlib.sha256(content).hexdigest(), now),
                )
            self.db.connection.execute(
                "UPDATE nodes SET snapshot_at=?,state='online',last_seen=?,last_success=?,updated_at=? WHERE id=?",
                (now, now, now, now, node_id),
            )
        self.db.audit("snapshot.record", node_id, profile_key)

    def record_local_snapshot(self, profile_key: str = "legacy") -> None:
        self.record_snapshot(
            self.local_snapshot(profile_key), role="federation" if self.is_federation() else "master"
        )

    def ensure_profile(self, name: str, selector: str, profile_key: str = "legacy",
                       token: str = "") -> sqlite3.Row:
        now = utc_now()
        name = safe_label(name)
        profile_key = safe_slug(profile_key)
        if token and not re.fullmatch(r"[A-Za-z0-9_-]{16,128}", token):
            raise ClusterError("订阅 token 无效")
        row = self.db.connection.execute("SELECT * FROM profiles WHERE name=?", (name,)).fetchone()
        if row is None and token:
            row = self.db.connection.execute("SELECT * FROM profiles WHERE token=?", (token,)).fetchone()
        if row:
            profile_token = token or str(row["token"])
            conflict = self.db.connection.execute(
                "SELECT id FROM profiles WHERE token=? AND id<>?", (profile_token, row["id"])
            ).fetchone()
            if conflict:
                raise ClusterError("订阅 token 已由其他档案使用")
            old_token = str(row["token"])
            with self.db.connection:
                self.db.connection.execute(
                    "UPDATE profiles SET name=?,token=?,selector=?,profile_key=?,enabled=1,updated_at=? WHERE id=?",
                    (name, profile_token, selector, profile_key, now, row["id"]),
                )
            if old_token != profile_token:
                shutil.rmtree(self.cache / old_token, ignore_errors=True)
                shutil.rmtree(self.root.parent / "weblun" / old_token, ignore_errors=True)
            return self.db.connection.execute("SELECT * FROM profiles WHERE id=?", (row["id"],)).fetchone()
        profile_token = token or b64url(secrets.token_bytes(24))
        with self.db.connection:
            self.db.connection.execute(
                "INSERT INTO profiles(name,token,selector,profile_key,created_at,updated_at) VALUES(?,?,?,?,?,?)",
                (name, profile_token, selector, profile_key, now, now),
            )
        return self.db.connection.execute("SELECT * FROM profiles WHERE name=?", (name,)).fetchone()

    @staticmethod
    def federation_profile_entity_key(selector: str, profile_key: str) -> str:
        identity = safe_slug(profile_key) + "\0" + selector
        return "profile:" + hashlib.sha256(identity.encode("utf-8")).hexdigest()

    def publish_local_profile_events(self) -> dict[str, int]:
        if not self.is_federation():
            return {"profiles": 0, "events": 0}
        profiles = self.db.connection.execute(
            "SELECT name,token,selector,profile_key FROM profiles WHERE enabled=1 ORDER BY id"
        ).fetchall()
        events = 0
        for profile in profiles:
            payload = {key: str(profile[key]) for key in ("name", "token", "selector", "profile_key")}
            entity_key = self.federation_profile_entity_key(payload["selector"], payload["profile_key"])
            events += int(self._create_event_if_changed("profile.upsert", entity_key, payload) is not None)
        self.db.audit("federation.profiles.publish", str(self.load_config().get("node_id", "")),
                      f"profiles={len(profiles)} events={events}")
        return {"profiles": len(profiles), "events": events}

    def profiles(self) -> list[dict[str, Any]]:
        return [dict(row) for row in self.db.connection.execute(
            "SELECT * FROM profiles WHERE enabled=1 ORDER BY id"
        )]

    def refresh_profiles(self, profile_key: str = "legacy",
                         sync_master_state: bool = True) -> list[dict[str, Any]]:
        config = self.load_config()
        if config.get("role") == "master" and sync_master_state:
            self.record_local_snapshot(profile_key)
            local = self.node(str(config.get("node_id", "")))
            self.mark_identity_synced(local)
            for node in list(self.db.connection.execute(
                "SELECT * FROM nodes WHERE role='child' ORDER BY server_number,id"
            )):
                if not self.identity_sync_pending(node):
                    continue
                try:
                    push_node_identity(self, str(node["id"]))
                except ClusterError as exc:
                    self.db.audit("identity.sync.pending", str(node["id"]), str(exc)[-2000:])
        self.ensure_profile("全部节点", "all")
        for row in self.db.connection.execute(
            "SELECT DISTINCT country_code FROM nodes WHERE country_code<>'ZZ' ORDER BY country_code"
        ):
            self.ensure_profile(f"{row['country_code']} 地区", f"region:{row['country_code']}")
        self.publish_local_profile_events()
        webroot = self.root.parent / "weblun"
        result: list[dict[str, Any]] = []
        all_profiles = self.db.connection.execute("SELECT * FROM profiles ORDER BY id").fetchall()
        for profile in all_profiles:
            if not profile["enabled"]:
                shutil.rmtree(self.cache / profile["token"], ignore_errors=True)
                shutil.rmtree(webroot / profile["token"], ignore_errors=True)
                continue
            try:
                generated = self.aggregate(profile["selector"], profile["profile_key"] or profile_key)
            except ClusterError:
                shutil.rmtree(self.cache / profile["token"], ignore_errors=True)
                shutil.rmtree(webroot / profile["token"], ignore_errors=True)
                continue
            directory = self.cache / profile["token"]
            public_directory = webroot / profile["token"]
            directory.mkdir(parents=True, exist_ok=True)
            public_directory.mkdir(parents=True, exist_ok=True)
            for filename, content in generated.items():
                atomic_write(directory / filename, content, 0o644)
                atomic_write(public_directory / filename, content, 0o644)
            result.append({
                "id": profile["id"], "name": profile["name"], "token": profile["token"],
                "selector": profile["selector"], "path": str(directory),
            })
        self.db.audit("profiles.refresh", self.load_config().get("node_id", ""), str(len(result)))
        return result

    def subscription_catchup(self) -> dict[str, Any]:
        received: dict[str, int] = {}
        failures: dict[str, str] = {}
        if self.is_federation():
            try:
                self.publish_local_user_events()
            except (ClusterError, OSError, sqlite3.Error) as exc:
                self.db.set_setting("federation.users.pending", "1")
                failures["local-user-publish"] = exc.__class__.__name__
        peer_ids = [str(node["id"]) for node in self.trusted_federation_nodes()]
        synced, sync_failures = parallel_federation_sync(
            self, peer_ids, attempts=1, coordinate_failures=False
        )
        received.update({node_id: int(item.get("received", 0))
                         for node_id, item in synced.items()})
        failures.update(sync_failures)
        for node_id in sync_failures:
            self.db.audit("subscription.access.sync-failed", node_id, "parallel-sync")
        try:
            applied = self.apply_federation_users(refresh=False) if self.is_federation() else {}
        except (ClusterError, OSError, sqlite3.Error):
            applied = {"pending": True}
            failures["local-user-apply"] = "pending"
        refreshed = self.refresh_profiles()
        return {"debounced": False, "received": received, "failures": failures,
                "refreshed": len(refreshed), "users": applied}

    def subscription_access(self, token: str, *, now: int | None = None) -> dict[str, Any]:
        now = int(now or utc_now())
        if not isinstance(token, str) or not re.fullmatch(r"[A-Za-z0-9_-]{16,128}", token):
            raise ClusterError("订阅 token 无效")
        row = self.db.connection.execute(
            "SELECT 1 FROM profiles WHERE enabled=1 AND token=?", (token,)
        ).fetchone()
        if not row:
            raise ClusterError("订阅 token 不存在或已停用")
        digest = hashlib.sha256(token.encode("utf-8")).hexdigest()
        key = f"subscription.access.{digest}"
        last = int(self.db.setting(key, "0") or 0)
        if now - last < 30:
            return {"debounced": True, "received": {}, "failures": {}, "refreshed": 0}
        self.db.set_setting(key, now)
        self.db.audit("subscription.access", digest[:16], "catchup")
        return self.subscription_catchup()

    def assign_user_nodes(self, user_id: int, node_ids: Iterable[str]) -> None:
        selected = list(dict.fromkeys(str(self.node(node_id)["id"]) for node_id in node_ids))
        with self.db.connection:
            self.db.connection.execute("DELETE FROM user_nodes WHERE user_id=?", (user_id,))
            self.db.connection.executemany(
                "INSERT INTO user_nodes(user_id,node_id,created_at) VALUES(?,?,?)",
                ((user_id, node_id, utc_now()) for node_id in selected),
            )
        self.db.audit("user.nodes", str(user_id), ",".join(short_id(item) for item in selected))

    def record_usage(self, node_id: str, device_uuid: str, epoch: str, uplink: int, downlink: int,
                     month_uplink: int, month_downlink: int, sequence: int) -> bool:
        self.node(node_id)
        if not re.fullmatch(r"[0-9A-Za-z._:-]{1,128}", epoch):
            raise ClusterError("流量结算周期无效")
        values = [uplink, downlink, month_uplink, month_downlink, sequence]
        if any(int(value) < 0 for value in values):
            raise ClusterError("流量计数不能为负数")
        existing = self.db.connection.execute(
            "SELECT sequence FROM usage_reports WHERE node_id=? AND device_uuid=? AND epoch=?",
            (node_id, device_uuid, epoch),
        ).fetchone()
        if existing and int(existing["sequence"]) > int(sequence):
            return False
        with self.db.connection:
            self.db.connection.execute(
                """INSERT INTO usage_reports(node_id,device_uuid,epoch,uplink,downlink,month_uplink,
                month_downlink,sequence,reported_at) VALUES(?,?,?,?,?,?,?,?,?)
                ON CONFLICT(node_id,device_uuid,epoch) DO UPDATE SET uplink=excluded.uplink,
                downlink=excluded.downlink,month_uplink=excluded.month_uplink,
                month_downlink=excluded.month_downlink,sequence=excluded.sequence,
                reported_at=excluded.reported_at""",
                (node_id, device_uuid, epoch, int(uplink), int(downlink), int(month_uplink),
                 int(month_downlink), int(sequence), utc_now()),
            )
        return True

    def global_usage(self, device_uuid: str, epoch: str) -> dict[str, int]:
        row = self.db.connection.execute(
            """SELECT COALESCE(SUM(uplink),0) uplink,COALESCE(SUM(downlink),0) downlink,
            COALESCE(SUM(month_uplink),0) month_uplink,COALESCE(SUM(month_downlink),0) month_downlink
            FROM usage_reports WHERE device_uuid=? AND epoch=?""",
            (device_uuid, epoch),
        ).fetchone()
        return {key: int(row[key]) for key in row.keys()}

    def push_usage_events(self) -> int:
        """Report absolute counters only after the adaptive traffic threshold is crossed."""
        config = self.load_config()
        if not config.get("enabled") or (config.get("role") == "child" and not config.get("paired")):
            return 0
        database = self.root / "modules" / "multiuser" / "data" / "lun.db"
        if not database.exists():
            return 0
        source = sqlite3.connect(f"file:{database}?mode=ro", uri=True, timeout=5)
        source.row_factory = sqlite3.Row
        try:
            rows = source.execute(
                """SELECT d.uuid,u.lifetime_quota,u.monthly_quota,t.period_start,
                COALESCE(SUM(t.uplink),0) uplink,COALESCE(SUM(t.downlink),0) downlink,
                COALESCE(SUM(t.month_uplink),0) month_uplink,
                COALESCE(SUM(t.month_downlink),0) month_downlink
                FROM devices d JOIN users u ON u.id=d.user_id
                JOIN usage_totals t ON t.device_id=d.id
                WHERE u.cluster_managed=?
                GROUP BY d.uuid,u.lifetime_quota,u.monthly_quota,t.period_start""",
                (1 if config.get("role") == "child" else 0,),
            ).fetchall()
        except sqlite3.Error:
            return 0
        finally:
            source.close()
        sent = 0
        for row in rows:
            total = int(row["uplink"]) + int(row["downlink"])
            month_total = int(row["month_uplink"]) + int(row["month_downlink"])
            state_key = f"usage-sent:{row['uuid']}:{row['period_start']}"
            try:
                state = json.loads(self.db.setting(state_key, "{}"))
            except json.JSONDecodeError:
                state = {}
            quota = int(row["monthly_quota"] or row["lifetime_quota"] or 0)
            global_used = int(state.get("global_month", 0) if row["monthly_quota"] else state.get("global_total", 0))
            threshold = self.usage_threshold(quota, global_used)
            previous = int(state.get("local_total", -1))
            delta = max(0, total - max(previous, 0))
            estimate = global_used + delta
            crossed = bool(quota and any(global_used < quota * mark <= estimate for mark in (0.80, 0.95, 1.0)))
            if previous >= 0 and total >= previous and delta < threshold and not crossed:
                continue
            sequence = int(state.get("sequence", 0)) + 1
            report = {
                "node_id": config["node_id"], "device_uuid": row["uuid"],
                "epoch": row["period_start"], "uplink": int(row["uplink"]),
                "downlink": int(row["downlink"]), "month_uplink": int(row["month_uplink"]),
                "month_downlink": int(row["month_downlink"]), "sequence": sequence,
            }
            if self.is_federation():
                self.create_event("usage.absolute", f"usage:{row['uuid']}:{row['period_start']}:{config['node_id']}", report)
                totals = self.global_usage(row["uuid"], row["period_start"])
            elif config.get("role") == "master":
                self.record_usage(**report)
                totals = self.global_usage(row["uuid"], row["period_start"])
            else:
                response = mutual_request(
                    self, config["controller_host"], int(config["controller_port"]),
                    "POST", "/v1/events/usage", {"report": report}, timeout=30,
                )
                totals = response.get("totals", {})
            self.db.set_setting(state_key, json_dumps({
                "local_total": total, "local_month": month_total, "sequence": sequence,
                "global_total": int(totals.get("uplink", 0)) + int(totals.get("downlink", 0)),
                "global_month": int(totals.get("month_uplink", 0)) + int(totals.get("month_downlink", 0)),
                "updated_at": utc_now(),
            }))
            sent += 1
        return sent

    @staticmethod
    def usage_threshold(quota: int, used: int) -> int:
        gib = 1024 ** 3
        if quota <= 0:
            return 10 * gib
        ratio = used / quota
        if ratio >= 0.95:
            return gib
        if ratio >= 0.80:
            return 5 * gib
        return 10 * gib

    def _selected_nodes(self, selector: str, profile_key: str) -> list[sqlite3.Row]:
        clauses = ["s.profile_key=?"]
        params: list[Any] = [profile_key]
        if self.is_federation():
            clauses.append("EXISTS(SELECT 1 FROM federation_keys fk WHERE fk.node_id=n.id AND fk.revoked_at=0)")
        if selector.startswith("region:"):
            code = normalize_country_code(selector.split(":", 1)[1])
            clauses.append("n.country_code=?")
            params.append(code)
        elif selector.startswith("nodes:"):
            ids = [item for item in selector.split(":", 1)[1].split(",") if re.fullmatch(r"[0-9a-f]{32}", item)]
            if not ids:
                return []
            clauses.append("n.id IN (%s)" % ",".join("?" for _ in ids))
            params.extend(ids)
        elif selector != "all":
            raise ClusterError("订阅选择器无效")
        query = (
            "SELECT DISTINCT n.* FROM nodes n JOIN snapshots s ON s.node_id=n.id WHERE "
            + " AND ".join(clauses) + " ORDER BY n.country_code,n.region,n.remark,n.id"
        )
        return list(self.db.connection.execute(query, params))

    @staticmethod
    def node_prefix(node: sqlite3.Row) -> str:
        return f"[{chinese_place(dict(node))}]"

    def node_subscription_names(self, value: str, node: sqlite3.Row) -> str:
        value = canonical_subscription_names(value)
        base = chinese_place(dict(node))
        display = self.identity_place(node)
        return re.sub(r"\[" + re.escape(base) + r"\d*\]", f"[{display}]", value)

    def node_subscription_value(self, value: Any, node: sqlite3.Row) -> Any:
        if isinstance(value, str):
            return self.node_subscription_names(value, node)
        if isinstance(value, list):
            return [self.node_subscription_value(item, node) for item in value]
        if isinstance(value, dict):
            return {key: self.node_subscription_value(item, node) for key, item in value.items()}
        return value

    @staticmethod
    def _prefix_generic_line(line: str, prefix: str) -> str:
        line = line.strip()
        return line

    @staticmethod
    def _extract_clash_blocks(text: str, prefix: str) -> list[tuple[str, list[str]]]:
        lines = text.splitlines()
        try:
            start = lines.index("proxies:") + 1
            end = lines.index("proxy-groups:")
        except ValueError:
            return []
        blocks: list[list[str]] = []
        current: list[str] = []
        for line in lines[start:end]:
            if line.startswith("- name:") and current:
                blocks.append(current)
                current = []
            if line.strip():
                current.append(line)
        if current:
            blocks.append(current)
        result: list[tuple[str, list[str]]] = []
        for block in blocks:
            match = re.match(r"- name:\s*[\"']?(.+?)[\"']?\s*$", block[0])
            if not match:
                continue
            name = match.group(1)
            updated = list(block)
            updated[0] = "- name: " + json.dumps(name, ensure_ascii=False)
            result.append((name, updated))
        return result

    def aggregate(self, selector: str = "all", profile_key: str = "legacy") -> dict[str, str]:
        nodes = self._selected_nodes(selector, profile_key)
        generic: list[str] = []
        clash_blocks: list[list[str]] = []
        clash_names: list[str] = []
        singbox_proxies: list[dict[str, Any]] = []
        singbox_base: dict[str, Any] | None = None
        region_names: dict[str, list[str]] = {}
        region_tags: dict[str, list[str]] = {}
        seen_generic: set[str] = set()
        seen_tags: set[str] = set()
        for node in nodes:
            prefix = self.node_prefix(node)
            rows = {row["filename"]: bytes(row["content"]) for row in self.db.connection.execute(
                "SELECT filename,content FROM snapshots WHERE node_id=? AND profile_key=?",
                (node["id"], profile_key),
            )}
            if "jhsub.txt" in rows:
                generic_text = self.node_subscription_names(
                    rows["jhsub.txt"].decode("utf-8", errors="replace"), node
                )
                for raw in generic_text.splitlines():
                    line = self._prefix_generic_line(raw, prefix)
                    if line and line not in seen_generic:
                        generic.append(line)
                        seen_generic.add(line)
            if "clmi.yaml" in rows:
                clash_text = self.node_subscription_names(
                    rows["clmi.yaml"].decode("utf-8", errors="replace"), node
                )
                for name, block in self._extract_clash_blocks(clash_text, prefix):
                    if name not in clash_names:
                        clash_names.append(name)
                        clash_blocks.append(block)
                        region_names.setdefault(node["country_code"], []).append(name)
            if "sbox.json" in rows:
                with contextlib.suppress(json.JSONDecodeError):
                    data = self.node_subscription_value(
                        canonicalize_subscription_value(json.loads(rows["sbox.json"].decode("utf-8"))), node
                    )
                    if singbox_base is None:
                        singbox_base = data
                    for outbound in data.get("outbounds", []):
                        if outbound.get("type") not in PROXY_OUTBOUND_TYPES:
                            continue
                        item = json.loads(json.dumps(outbound))
                        tag = item.get("tag") or item.get("type", "node")
                        if tag in seen_tags:
                            continue
                        item["tag"] = tag
                        singbox_proxies.append(item)
                        seen_tags.add(tag)
                        region_tags.setdefault(node["country_code"], []).append(tag)
        if not generic and not clash_names and not singbox_proxies:
            raise ClusterError("所选服务器没有可聚合的订阅快照")
        clash = self._build_clash(clash_blocks, clash_names, region_names)
        singbox = self._build_singbox(singbox_base or {}, singbox_proxies, region_tags)
        return {"jhsub.txt": "\n".join(generic) + ("\n" if generic else ""), "clmi.yaml": clash, "sbox.json": singbox}

    @staticmethod
    def _build_clash(blocks: list[list[str]], names: list[str], regions: dict[str, list[str]]) -> str:
        output = [
            "mixed-port: 7890", "allow-lan: true", "mode: rule", "log-level: info",
            "proxies:",
        ]
        for block in blocks:
            output.extend(block)
        output.append("proxy-groups:")
        output.extend([
            '- name: "Lun 手动选择"', "  type: select", "  proxies:",
            *[f"    - {json.dumps(name, ensure_ascii=False)}" for name in names],
        ])
        output.extend([
            '- name: "Lun 自动选择"', "  type: url-test", "  url: https://www.gstatic.com/generate_204",
            "  interval: 300", "  tolerance: 50", "  proxies:",
            *[f"    - {json.dumps(name, ensure_ascii=False)}" for name in names],
        ])
        for code, region_nodes in sorted(regions.items()):
            if not region_nodes:
                continue
            output.extend([
                f"- name: {json.dumps('Lun ' + (code or 'ZZ'), ensure_ascii=False)}", "  type: url-test",
                "  url: https://www.gstatic.com/generate_204", "  interval: 300", "  tolerance: 50", "  proxies:",
                *[f"    - {json.dumps(name, ensure_ascii=False)}" for name in region_nodes],
            ])
        output.extend(["rules:", "  - GEOIP,LAN,DIRECT", "  - GEOIP,CN,DIRECT", "  - MATCH,Lun 手动选择"])
        return "\n".join(output) + "\n"

    @staticmethod
    def _build_singbox(base: dict[str, Any], proxies: list[dict[str, Any]], regions: dict[str, list[str]]) -> str:
        tags = [item["tag"] for item in proxies]
        outbounds = list(proxies)
        outbounds.append({"type": "urltest", "tag": "Lun 自动选择", "outbounds": tags,
                          "url": "https://www.gstatic.com/generate_204", "interval": "5m", "tolerance": 50})
        for code, region_tags in sorted(regions.items()):
            if region_tags:
                outbounds.append({"type": "urltest", "tag": f"Lun {code or 'ZZ'}", "outbounds": region_tags,
                                  "url": "https://www.gstatic.com/generate_204", "interval": "5m", "tolerance": 50})
        outbounds.append({"type": "selector", "tag": "Lun 手动选择", "outbounds": ["Lun 自动选择", *tags],
                          "default": "Lun 自动选择"})
        outbounds.append({"type": "direct", "tag": "direct"})
        result = {
            "log": base.get("log", {"level": "info", "timestamp": True}),
            "dns": base.get("dns", {"servers": [{"type": "local", "tag": "local"}]}),
            "inbounds": base.get("inbounds", []), "outbounds": outbounds,
            "route": {"rules": base.get("route", {}).get("rules", []), "final": "Lun 手动选择"},
        }
        return json.dumps(result, ensure_ascii=False, indent=2) + "\n"

    def write_aggregate(self, selector: str = "all", profile_key: str = "legacy") -> dict[str, str]:
        generated = self.aggregate(selector, profile_key)
        directory = self.cache / safe_slug(f"{profile_key}-{selector}")
        directory.mkdir(parents=True, exist_ok=True)
        for filename, content in generated.items():
            atomic_write(directory / filename, content, 0o644)
        return {name: str(directory / name) for name in generated}

    @property
    def role_transfer_dir(self) -> Path:
        return self.module / "role-transfer"

    def create_role_recovery(self, label: str) -> Path:
        self.backups.mkdir(parents=True, exist_ok=True)
        target = self.backups / f"role-{safe_slug(label)}-{utc_now()}-{secrets.token_hex(3)}.tar.gz"
        with tempfile.TemporaryDirectory(dir=self.module) as temporary:
            database_copy = Path(temporary) / "cluster.db"
            destination = sqlite3.connect(database_copy)
            try:
                self.db.connection.backup(destination)
            finally:
                destination.close()
            with tarfile.open(target, "w:gz") as archive:
                if self.config_path.exists():
                    archive.add(self.config_path, arcname="config.json", recursive=False)
                archive.add(database_copy, arcname="data/cluster.db", recursive=False)
                for path in self.pki.glob("*"):
                    if path.is_file():
                        archive.add(path, arcname=f"pki/{path.name}", recursive=False)
        os.chmod(target, 0o600)
        return target

    def restore_role_recovery(self, source: Path) -> None:
        if source.parent.resolve() != self.backups.resolve() or not source.is_file():
            raise ClusterError("角色切换恢复文件无效")
        with tempfile.TemporaryDirectory(dir=self.module) as temporary:
            extract = Path(temporary) / "extract"
            extract.mkdir()
            with tarfile.open(source, "r:gz") as archive:
                members = archive.getmembers()
                allowed = {"config.json", "data/cluster.db"}
                if not members or any(
                    not member.isfile() or not (
                        member.name in allowed
                        or (member.name.startswith("pki/") and "/" not in member.name[len("pki/"):])
                    )
                    for member in members
                ):
                    raise ClusterError("角色切换恢复文件内容无效")
                for member in members:
                    destination = (extract / member.name).resolve()
                    if extract.resolve() not in destination.parents:
                        raise ClusterError("角色切换恢复文件包含不安全路径")
                archive.extractall(extract, filter="data")
            if not (extract / "config.json").is_file() or not (extract / "data" / "cluster.db").is_file():
                raise ClusterError("角色切换恢复文件不完整")
            shutil.copy2(extract / "config.json", self.config_path)
            self.replace_database(extract / "data" / "cluster.db")
            if (extract / "pki").exists():
                shutil.rmtree(self.pki, ignore_errors=True)
                shutil.copytree(extract / "pki", self.pki)
        self.secure_files()

    def build_role_transfer(self, target_id: str) -> bytes:
        config = self.load_config()
        if config.get("role") != "master":
            raise ClusterError("只有当前主 VPS 可以发起角色互换")
        target = self.node(target_id)
        if target["role"] != "child":
            raise ClusterError("只能把子 VPS 提升为主 VPS")
        with tempfile.TemporaryDirectory(dir=self.module) as temporary:
            archive_path = Path(temporary) / "role-transfer.tar.gz"
            database_copy = Path(temporary) / "cluster.db"
            destination = sqlite3.connect(database_copy)
            try:
                self.db.connection.backup(destination)
            finally:
                destination.close()
            manifest = {
                "format": 1, "api_version": API_VERSION, "created_at": utc_now(),
                "cluster_id": config.get("cluster_id", ""), "source_id": config.get("node_id", ""),
                "target_id": str(target["id"]),
            }
            manifest_path = Path(temporary) / "manifest.json"
            manifest_path.write_text(json.dumps(manifest, ensure_ascii=False), encoding="utf-8")
            with tarfile.open(archive_path, "w:gz") as archive:
                archive.add(manifest_path, arcname="manifest.json", recursive=False)
                archive.add(database_copy, arcname="data/cluster.db", recursive=False)
                for name in ("cluster-ca.crt", "cluster-ca.key"):
                    path = self.pki / name
                    if not path.is_file():
                        raise ClusterError("主 VPS 集群 CA 不完整，无法切换角色")
                    archive.add(path, arcname=f"pki/{name}", recursive=False)
            payload = archive_path.read_bytes()
        if len(payload) > ROLE_TRANSFER_MAX:
            raise ClusterError("集群控制数据超过 32 MiB，请先清理旧快照或加载备份后再切换")
        return payload

    def stage_role_transfer(self, payload: dict[str, Any], peer_id: str) -> dict[str, Any]:
        config = self.load_config()
        if config.get("role") != "child" or config.get("controller_id") != peer_id:
            raise ClusterError("只有当前主 VPS 可以向子 VPS 传送接管数据")
        transfer_id = str(payload.get("transfer_id", ""))
        digest = str(payload.get("sha256", ""))
        source_id = str(payload.get("source_id", ""))
        target_id = str(payload.get("target_id", ""))
        try:
            index = int(payload.get("index", -1))
            total = int(payload.get("total", 0))
            size = int(payload.get("size", 0))
        except (TypeError, ValueError) as exc:
            raise ClusterError("角色切换分片参数无效") from exc
        if not re.fullmatch(r"[0-9a-f]{32}", transfer_id) or not re.fullmatch(r"[0-9a-f]{64}", digest):
            raise ClusterError("角色切换传输身份无效")
        if source_id != peer_id or target_id != config.get("node_id"):
            raise ClusterError("角色切换源或目标身份不匹配")
        max_chunks = (ROLE_TRANSFER_MAX + ROLE_TRANSFER_CHUNK - 1) // ROLE_TRANSFER_CHUNK
        if total < 1 or total > max_chunks or index < 0 or index >= total or size < 1 or size > ROLE_TRANSFER_MAX:
            raise ClusterError("角色切换分片范围无效")
        try:
            chunk = base64.b64decode(str(payload.get("data", "")).encode(), validate=True)
        except (ValueError, binascii.Error) as exc:
            raise ClusterError("角色切换分片编码无效") from exc
        if not chunk or len(chunk) > ROLE_TRANSFER_CHUNK:
            raise ClusterError("角色切换分片大小无效")
        self.role_transfer_dir.mkdir(parents=True, exist_ok=True)
        with contextlib.suppress(OSError):
            os.chmod(self.role_transfer_dir, 0o700)
        now = utc_now()
        for directory in self.role_transfer_dir.iterdir():
            with contextlib.suppress(OSError):
                if directory.is_dir() and now - int(directory.stat().st_mtime) > ROLE_TRANSFER_TTL:
                    shutil.rmtree(directory, ignore_errors=True)
        directory = self.role_transfer_dir / transfer_id
        directory.mkdir(mode=0o700, exist_ok=True)
        metadata = {
            "transfer_id": transfer_id, "sha256": digest, "source_id": source_id,
            "target_id": target_id, "total": total, "size": size, "created_at": now,
        }
        metadata_path = directory / "metadata.json"
        if metadata_path.exists():
            try:
                existing = json.loads(metadata_path.read_text(encoding="utf-8"))
            except (OSError, json.JSONDecodeError) as exc:
                raise ClusterError("角色切换暂存数据损坏") from exc
            comparable = {key: existing.get(key) for key in metadata if key != "created_at"}
            expected = {key: metadata[key] for key in metadata if key != "created_at"}
            if comparable != expected:
                raise ClusterError("角色切换分片元数据不一致")
        else:
            atomic_write(metadata_path, json.dumps(metadata, ensure_ascii=False) + "\n")
        atomic_write(directory / f"{index:04d}.part", chunk)
        received = len(list(directory.glob("*.part")))
        return {"transfer_id": transfer_id, "received": received, "total": total}

    def _load_staged_role_transfer(self, transfer_id: str, peer_id: str) -> tuple[bytes, dict[str, Any]]:
        if not re.fullmatch(r"[0-9a-f]{32}", transfer_id):
            raise ClusterError("角色切换传输身份无效")
        directory = self.role_transfer_dir / transfer_id
        try:
            metadata = json.loads((directory / "metadata.json").read_text(encoding="utf-8"))
        except (OSError, json.JSONDecodeError) as exc:
            raise ClusterError("角色切换数据尚未传输完成") from exc
        if metadata.get("source_id") != peer_id or metadata.get("target_id") != self.load_config().get("node_id"):
            raise ClusterError("角色切换暂存身份不匹配")
        if utc_now() - int(metadata.get("created_at", 0)) > ROLE_TRANSFER_TTL:
            raise ClusterError("角色切换暂存数据已过期")
        total = int(metadata.get("total", 0))
        chunks: list[bytes] = []
        for index in range(total):
            path = directory / f"{index:04d}.part"
            if not path.is_file():
                raise ClusterError(f"角色切换缺少分片 {index + 1}/{total}")
            chunks.append(path.read_bytes())
        data = b"".join(chunks)
        if len(data) != int(metadata.get("size", 0)) or len(data) > ROLE_TRANSFER_MAX:
            raise ClusterError("角色切换数据大小不匹配")
        if not hmac.compare_digest(hashlib.sha256(data).hexdigest(), str(metadata.get("sha256", ""))):
            raise ClusterError("角色切换数据校验失败")
        return data, metadata

    def discard_role_transfer(self, transfer_id: str, peer_id: str) -> dict[str, Any]:
        config = self.load_config()
        authorized = (
            (config.get("role") == "child" and config.get("controller_id") == peer_id)
            or (
                config.get("role") == "master" and config.get("role_switch_pending")
                and config.get("role_switch_source_id") == peer_id
            )
        )
        if not authorized or not re.fullmatch(r"[0-9a-f]{32}", transfer_id):
            raise ClusterError("无权清理该角色切换暂存数据")
        shutil.rmtree(self.role_transfer_dir / transfer_id, ignore_errors=True)
        return {"discarded": transfer_id}

    def promote_from_role_transfer(self, transfer_id: str, peer_id: str) -> dict[str, Any]:
        current = self.load_config()
        if current.get("role") != "child" or current.get("controller_id") != peer_id:
            raise ClusterError("当前服务器不是该主 VPS 的子 VPS")
        data, metadata = self._load_staged_role_transfer(transfer_id, peer_id)
        recovery = self.create_role_recovery("before-promote")
        replaced = False
        try:
            with tempfile.TemporaryDirectory(dir=self.module) as temporary:
                archive_path = Path(temporary) / "role-transfer.tar.gz"
                archive_path.write_bytes(data)
                extract = Path(temporary) / "extract"
                extract.mkdir()
                with tarfile.open(archive_path, "r:gz") as archive:
                    members = archive.getmembers()
                    allowed = {"manifest.json", "data/cluster.db", "pki/cluster-ca.crt", "pki/cluster-ca.key"}
                    if {member.name for member in members} != allowed or any(not member.isfile() for member in members):
                        raise ClusterError("角色切换包内容无效")
                    for member in members:
                        destination = (extract / member.name).resolve()
                        if extract.resolve() not in destination.parents:
                            raise ClusterError("角色切换包包含不安全路径")
                    archive.extractall(extract, filter="data")
                manifest = json.loads((extract / "manifest.json").read_text(encoding="utf-8"))
                if (
                    int(manifest.get("format", 0)) != 1
                    or int(manifest.get("api_version", 0)) > API_VERSION
                    or manifest.get("cluster_id") != current.get("cluster_id")
                    or manifest.get("source_id") != peer_id
                    or manifest.get("target_id") != current.get("node_id")
                ):
                    raise ClusterError("角色切换包与当前集群不匹配")
                supplied_ca = (extract / "pki" / "cluster-ca.crt").read_bytes()
                if not (self.pki / "cluster-ca.crt").is_file() or supplied_ca != (self.pki / "cluster-ca.crt").read_bytes():
                    raise ClusterError("角色切换包的集群 CA 与本机不一致")
                candidate = sqlite3.connect(extract / "data" / "cluster.db")
                try:
                    if candidate.execute("PRAGMA integrity_check").fetchone()[0] != "ok":
                        raise ClusterError("角色切换数据库完整性检查失败")
                    ids = {row[0] for row in candidate.execute("SELECT id FROM nodes")}
                finally:
                    candidate.close()
                if peer_id not in ids or current["node_id"] not in ids:
                    raise ClusterError("角色切换数据库缺少主机或目标子机")
                self.replace_database(extract / "data" / "cluster.db")
                shutil.copy2(extract / "pki" / "cluster-ca.crt", self.pki / "cluster-ca.crt")
                shutil.copy2(extract / "pki" / "cluster-ca.key", self.pki / "cluster-ca.key")
                os.chmod(self.pki / "cluster-ca.crt", 0o644)
                os.chmod(self.pki / "cluster-ca.key", 0o600)
                replaced = True
            with self.db.connection:
                self.db.connection.execute("UPDATE nodes SET role='child' WHERE id=?", (peer_id,))
                self.db.connection.execute("UPDATE nodes SET role='master' WHERE id=?", (current["node_id"],))
                self.db.connection.execute(
                    "UPDATE nodes SET endpoint_host=?,endpoint_port=?,internal_port=?,remark=?,updated_at=? WHERE id=?",
                    (current["public_host"], int(current["public_port"]), int(current["internal_port"]),
                     safe_label(str(current.get("remark", ""))), utc_now(), current["node_id"]),
                )
            target = self.node(str(current["node_id"]))
            location = {key: target[key] for key in ("country_code", "country", "region", "city", "provider")}
            for key in ("controller_id", "controller_host", "controller_port", "pending_controller"):
                current.pop(key, None)
            current.update({
                "role": "master", "paired": True, "server_number": int(target["server_number"]),
                "location": self.normalize_identity_location(location),
                "role_switch_pending": True, "role_switch_source_id": peer_id,
                "role_switch_transfer_id": transfer_id, "role_switch_recovery": str(recovery),
            })
            self.save_config(current)
            self.apply_local_identity(
                int(target["server_number"]), location, self.identity_place(target)
            )
            self.db.audit("role.promote", current["node_id"], f"from={short_id(peer_id)}")
            shutil.rmtree(self.role_transfer_dir / transfer_id, ignore_errors=True)
            return {"role": "master", "node_id": current["node_id"], "restart_required": True}
        except Exception:
            if replaced:
                with contextlib.suppress(Exception):
                    self.restore_role_recovery(recovery)
            raise

    def rollback_role_promotion(self, peer_id: str) -> dict[str, Any]:
        config = self.load_config()
        if config.get("role") != "master" or not config.get("role_switch_pending"):
            raise ClusterError("当前没有待确认的主 VPS 提升")
        if config.get("role_switch_source_id") != peer_id:
            raise ClusterError("只有原主 VPS 可以撤销本次提升")
        recovery = Path(str(config.get("role_switch_recovery", "")))
        self.restore_role_recovery(recovery)
        self.db.audit("role.rollback", self.load_config().get("node_id", ""), f"to={short_id(peer_id)}")
        return {"role": self.load_config().get("role"), "restart_required": True}

    def finalize_role_promotion(self, peer_id: str) -> dict[str, Any]:
        config = self.load_config()
        if config.get("role") != "master" or not config.get("role_switch_pending"):
            raise ClusterError("当前没有待确认的主 VPS 提升")
        if config.get("role_switch_source_id") != peer_id:
            raise ClusterError("只有原主 VPS 可以完成本次切换")
        previous = str(config.pop("role_switch_source_id", ""))
        recovery = str(config.pop("role_switch_recovery", ""))
        config.pop("role_switch_transfer_id", None)
        config.pop("role_switch_pending", None)
        config["previous_master_id"] = previous
        self.save_config(config)
        self.refresh_profiles()
        self.db.audit("role.finalize", config["node_id"], f"previous={short_id(previous)}")
        return {"role": "master", "node_id": config["node_id"], "recovery": recovery}

    def create_snapshot(self, label: str = "manual") -> Path:
        self.backups.mkdir(parents=True, exist_ok=True)
        target = self.backups / f"node-{utc_now()}-{secrets.token_hex(3)}-{safe_slug(label)}.tar.gz"
        with tarfile.open(target, "w:gz") as archive:
            excluded = {
                "xray", "x", "sing-box", "s", "cloudflared", "c", "modules",
                "xray-access.log", "singbox-access.log", "argo.log",
            }
            for path in self.root.iterdir():
                if (not path.is_file() or path.name in excluded or path.stat().st_size > MAX_BODY):
                    continue
                archive.add(path, arcname=f"lun/{path.name}", recursive=False)
            for name in ("xray", "sing-box"):
                path = self.root / name
                if path.is_file():
                    archive.add(path, arcname=f"core/{name}", recursive=False)
        os.chmod(target, 0o600)
        self.db.audit("snapshot.create", self.load_config().get("node_id", ""), target.name)
        return target

    def restore_snapshot(self, source: Path) -> dict[str, Any]:
        if source.parent.resolve() != self.backups.resolve() or not source.is_file():
            raise ClusterError("快照路径无效")
        rollback = self.create_snapshot("before-snapshot-restore")
        with tempfile.TemporaryDirectory(dir=self.module) as temporary:
            extract = Path(temporary) / "extract"
            extract.mkdir()
            with tarfile.open(source, "r:gz") as archive:
                members = archive.getmembers()
                if not members or any(
                    not member.isfile() or not (
                        (member.name.startswith("lun/") and "/" not in member.name[len("lun/"):])
                        or member.name in {"core/xray", "core/sing-box"}
                    )
                    for member in members
                ):
                    raise ClusterError("快照内容无效")
                for member in members:
                    destination = (extract / member.name).resolve()
                    if extract.resolve() not in destination.parents:
                        raise ClusterError("快照包含不安全路径")
                archive.extractall(extract, filter="data")
            restored = extract / "lun"
            for path in self.root.glob("port_*"):
                if path.is_file():
                    path.unlink()
            for path in restored.iterdir():
                shutil.copy2(path, self.root / path.name)
            core = extract / "core"
            if core.exists():
                for path in core.iterdir():
                    shutil.copy2(path, self.root / path.name)
                    os.chmod(self.root / path.name, 0o755)
        self.db.audit("snapshot.restore", self.load_config().get("node_id", ""), source.name)
        return {"path": str(source), "rollback": str(rollback)}

    def export_backup(self, target: Path, password: str) -> Path:
        if self.is_federation():
            return self.export_federation_backup(target, password)
        if len(password) < 8:
            raise ClusterError("备份口令至少8个字符")
        self.db.connection.execute("PRAGMA wal_checkpoint(FULL)")
        with tempfile.TemporaryDirectory(dir=self.module) as temporary:
            archive = Path(temporary) / "cluster.tar.gz"
            manifest = {
                "format": 1, "cluster_id": self.load_config().get("cluster_id", ""),
                "node_id": self.load_config().get("node_id", ""), "created_at": utc_now(),
                "api_version": API_VERSION,
            }
            manifest_path = self.module / ".backup-manifest.json"
            atomic_write(manifest_path, json.dumps(manifest, ensure_ascii=False, indent=2) + "\n")
            try:
                with tarfile.open(archive, "w:gz") as tar:
                    for path, name in (
                        (self.config_path, "config.json"), (self.db.path, "data/cluster.db"),
                        (manifest_path, "manifest.json"),
                    ):
                        if path.exists():
                            tar.add(path, arcname=name, recursive=False)
                    for path in self.pki.glob("*"):
                        if path.is_file():
                            tar.add(path, arcname=f"pki/{path.name}", recursive=False)
                    if self.cache.exists():
                        tar.add(self.cache, arcname="generated")
                plaintext = archive.read_bytes()
            finally:
                manifest_path.unlink(missing_ok=True)
        salt = secrets.token_bytes(16)
        iv = secrets.token_bytes(16)
        material = hashlib.pbkdf2_hmac("sha256", password.encode(), salt, BACKUP_KDF_ITERATIONS, 64)
        encryption_key, mac_key = material[:32], material[32:]
        with tempfile.TemporaryDirectory() as temporary:
            source = Path(temporary) / "plain"
            ciphertext = Path(temporary) / "cipher"
            source.write_bytes(plaintext)
            executable = shutil.which("openssl")
            if not executable:
                raise ClusterError("加密备份需要 OpenSSL")
            self._run([
                executable, "enc", "-aes-256-cbc", "-K", encryption_key.hex(), "-iv", iv.hex(),
                "-in", str(source), "-out", str(ciphertext),
            ])
            encrypted = ciphertext.read_bytes()
        header = BACKUP_MAGIC + salt + iv
        tag = hmac.new(mac_key, header + encrypted, hashlib.sha256).digest()
        atomic_write(target, header + encrypted + tag)
        self.db.audit("backup.export", self.load_config().get("node_id", ""), target.name)
        return target

    def restore_backup(self, source: Path, password: str) -> dict[str, Any]:
        payload = source.read_bytes()
        minimum = len(BACKUP_MAGIC) + 16 + 16 + 32
        if len(payload) < minimum or not payload.startswith(BACKUP_MAGIC):
            raise ClusterError("不是有效的 Lun 集群备份")
        offset = len(BACKUP_MAGIC)
        salt, iv = payload[offset:offset + 16], payload[offset + 16:offset + 32]
        ciphertext, supplied_tag = payload[offset + 32:-32], payload[-32:]
        material = hashlib.pbkdf2_hmac("sha256", password.encode(), salt, BACKUP_KDF_ITERATIONS, 64)
        encryption_key, mac_key = material[:32], material[32:]
        expected = hmac.new(mac_key, payload[:-32], hashlib.sha256).digest()
        if not hmac.compare_digest(expected, supplied_tag):
            raise ClusterError("备份口令错误或文件已损坏")
        current = self.create_snapshot("before-cluster-restore")
        recovery = self.backups / f"cluster-state-before-restore-{utc_now()}.tar.gz"
        self.db.connection.execute("PRAGMA wal_checkpoint(FULL)")
        with tarfile.open(recovery, "w:gz") as archive:
            for path, name in ((self.config_path, "config.json"), (self.db.path, "data/cluster.db")):
                if path.exists():
                    archive.add(path, arcname=name, recursive=False)
            for path in self.pki.glob("*"):
                if path.is_file():
                    archive.add(path, arcname=f"pki/{path.name}", recursive=False)
        os.chmod(recovery, 0o600)
        with tempfile.TemporaryDirectory(dir=self.module) as temporary:
            cipher = Path(temporary) / "cipher"
            archive = Path(temporary) / "cluster.tar.gz"
            cipher.write_bytes(ciphertext)
            executable = shutil.which("openssl")
            if not executable:
                raise ClusterError("加载备份需要 OpenSSL")
            self._run([
                executable, "enc", "-d", "-aes-256-cbc", "-K", encryption_key.hex(), "-iv", iv.hex(),
                "-in", str(cipher), "-out", str(archive),
            ])
            extract = Path(temporary) / "extract"
            extract.mkdir()
            with tarfile.open(archive, "r:gz") as tar:
                members = tar.getmembers()
                for member in members:
                    destination = (extract / member.name).resolve()
                    if extract.resolve() not in destination.parents and destination != extract.resolve():
                        raise ClusterError("备份包含不安全路径")
                tar.extractall(extract, filter="data")
            manifest = json.loads((extract / "manifest.json").read_text(encoding="utf-8"))
            if int(manifest.get("api_version", 0)) > API_VERSION:
                raise ClusterError("备份来自更高版本，请先更新 Lun")
            shutil.copy2(extract / "config.json", self.config_path)
            self.replace_database(extract / "data" / "cluster.db")
            if (extract / "pki").exists():
                shutil.rmtree(self.pki, ignore_errors=True)
                shutil.copytree(extract / "pki", self.pki)
            if (extract / "generated").exists():
                shutil.rmtree(self.cache, ignore_errors=True)
                shutil.copytree(extract / "generated", self.cache)
        self.secure_files()
        self.db.audit("backup.restore", self.load_config().get("node_id", ""), source.name)
        return {"manifest": manifest, "pre_restore_snapshot": str(current),
                "pre_restore_cluster_state": str(recovery)}

    # Federation v3 ---------------------------------------------------------
    # Old master/child methods intentionally remain above: migration is explicit
    # and a failed rollout can still use the existing recovery path.
    def is_federation(self) -> bool:
        return self.load_config().get("mode") == "federation"

    def _create_federation_identity(self, node_id: str) -> None:
        self.pki.mkdir(parents=True, exist_ok=True)
        root_key, root_cert = self.pki / "federation-root.key", self.pki / "federation-root.crt"
        identity_key, identity_csr = self.pki / "federation-node.key", self.pki / "federation-node.csr"
        identity_cert = self.pki / "federation-node.crt"
        if not root_key.exists():
            self._openssl(["ecparam", "-genkey", "-name", "prime256v1", "-out", str(root_key)])
            self._openssl(["req", "-new", "-x509", "-sha256", "-days", "3650", "-key", str(root_key),
                           "-out", str(root_cert), "-subj", f"/CN=Lun Federation Root {node_id}"])
        if not identity_key.exists():
            self._openssl(["ecparam", "-genkey", "-name", "prime256v1", "-out", str(identity_key)])
            self._openssl(["req", "-new", "-key", str(identity_key), "-out", str(identity_csr),
                           "-subj", f"/CN={node_id}"])
            ext = self.pki / ".federation-node.ext"
            try:
                atomic_write(ext, "basicConstraints=critical,CA:FALSE\nkeyUsage=critical,digitalSignature\n"
                             "extendedKeyUsage=serverAuth,clientAuth\n"
                             f"subjectAltName=URI:lun-federation:{node_id}\n", 0o600)
                self._openssl(["x509", "-req", "-in", str(identity_csr), "-CA", str(root_cert),
                               "-CAkey", str(root_key), "-CAcreateserial", "-out", str(identity_cert),
                               "-days", "3650", "-sha256", "-extfile", str(ext)])
            finally:
                ext.unlink(missing_ok=True)
                identity_csr.unlink(missing_ok=True)
        self.secure_files()

    def _federation_init(self, public_host: str, internal_port: int, public_port: int | None = None,
                         remark: str = "", migrate: bool = False) -> dict[str, Any]:
        if not valid_port(internal_port) or not valid_port(public_port or internal_port):
            raise ClusterError("通信端口必须在 1-65535")
        old = self.load_config()
        if old.get("enabled") and old.get("mode") != "federation" and not migrate:
            raise ClusterError("旧主从集群需要使用 federation-init --migrate 显式迁移")
        node_id = str(old.get("node_id", "")) if re.fullmatch(r"[0-9a-f]{32}", str(old.get("node_id", ""))) else random_node_id()
        cluster_id = str(old.get("cluster_id", "")) if re.fullmatch(r"[0-9a-f]{32}", str(old.get("cluster_id", ""))) else uuid.uuid4().hex
        number = self.allocate_server_number(node_id, int(old.get("server_number", 1) or 1))
        location = self.normalize_identity_location(old.get("location"), str(old.get("place", "")))
        config = {**old, "enabled": True, "mode": "federation", "role": "federation", "cluster_id": cluster_id,
                  "node_id": node_id, "bind": str(old.get("bind", "0.0.0.0")),
                  "public_host": normalize_host(public_host), "internal_port": int(internal_port),
                  "public_port": int(public_port or internal_port), "remark": safe_label(remark or str(old.get("remark", ""))),
                  "server_number": number, "location": location, "paired": True, "created_at": int(old.get("created_at", utc_now())),
                  "federation_migrated_at": utc_now() if old.get("enabled") else 0}
        for key in ("controller_id", "controller_host", "controller_port", "pending_controller", "role_switch_pending"):
            config.pop(key, None)
        self._create_federation_identity(node_id)
        self.save_config(config)
        self.apply_local_identity(number, location, str(old.get("place", "")))
        self.upsert_node(self.local_status(), role="federation")
        self.register_federation_key(node_id, self.federation_root_certificate(), self.federation_identity_certificate())
        if not self.db.connection.execute("SELECT 1 FROM federation_events LIMIT 1").fetchone():
            self.create_event("member.upsert", f"member:{node_id}", self.federation_member_payload(
                self.local_status(), legacy_number=bool(migrate)
            ))
        self.ensure_profile("全部节点", "all")
        self.record_local_snapshot()
        self.db.audit("federation.init", node_id, "migrated" if migrate else "new")
        return config

    def federation_init(self, public_host: str, internal_port: int, public_port: int | None = None,
                        remark: str = "", migrate: bool = False) -> dict[str, Any]:
        if not migrate:
            return self._federation_init(public_host, internal_port, public_port, remark, False)
        self.backups.mkdir(parents=True, exist_ok=True)
        recovery = self.backups / f"legacy-cluster-rollback-{utc_now()}-{secrets.token_hex(3)}.tar.gz"
        with tempfile.TemporaryDirectory(dir=self.module) as temporary:
            db_copy = Path(temporary) / "cluster.db"
            destination = sqlite3.connect(db_copy)
            try:
                self.db.connection.backup(destination)
            finally:
                destination.close()
            old_names = {path.name for path in self.pki.iterdir() if path.is_file()} if self.pki.exists() else set()
            with tarfile.open(recovery, "w:gz") as archive:
                if self.config_path.is_file():
                    archive.add(self.config_path, arcname="config.json", recursive=False)
                archive.add(db_copy, arcname="data/cluster.db", recursive=False)
                for path in self.pki.iterdir() if self.pki.exists() else []:
                    if path.is_file():
                        archive.add(path, arcname=f"pki/{path.name}", recursive=False)
            os.chmod(recovery, 0o600)
            try:
                result = self._federation_init(public_host, internal_port, public_port, remark, True)
                migrated_users = self.publish_local_user_events()
                with self.db.connection:
                    self.db.connection.execute(
                        "UPDATE nodes SET role='legacy-candidate',state='legacy-unverified',updated_at=? WHERE id<>?",
                        (utc_now(), result["node_id"]),
                    )
                (self.pki / "cluster-ca.key").unlink(missing_ok=True)
                if (self.pki / "cluster-ca.key").exists():
                    raise ClusterError("旧共享 CA 私钥未退出活动 PKI")
                result = {**result, "legacy_rollback_archive": str(recovery),
                          "migrated_users": migrated_users}
                self.save_config(result)
                return result
            except Exception:
                self.replace_database(db_copy)
                with tarfile.open(recovery, "r:gz") as archive:
                    config_member = archive.getmember("config.json") if "config.json" in archive.getnames() else None
                    if config_member:
                        atomic_write(self.config_path, archive.extractfile(config_member).read(), 0o600)  # type: ignore[union-attr]
                    for path in list(self.pki.iterdir()) if self.pki.exists() else []:
                        if path.is_file() and path.name not in old_names:
                            path.unlink(missing_ok=True)
                    for member in archive.getmembers():
                        if member.isfile() and member.name.startswith("pki/") and "/" not in member.name[4:]:
                            atomic_write(self.pki / member.name[4:], archive.extractfile(member).read(), 0o600)  # type: ignore[union-attr]
                raise

    def migrate_to_federation(self) -> dict[str, Any]:
        config = self.load_config()
        return self.federation_init(str(config.get("public_host", "127.0.0.1")),
                                    int(config.get("internal_port", 0)), int(config.get("public_port", 0)) or None,
                                    str(config.get("remark", "")), migrate=True)

    def federation_root_certificate(self) -> str:
        path = self.pki / "federation-root.crt"
        if not path.is_file():
            raise ClusterError("联邦身份尚未初始化")
        return path.read_text(encoding="utf-8")

    def federation_identity_certificate(self) -> str:
        path = self.pki / "federation-node.crt"
        if not path.is_file():
            raise ClusterError("联邦身份尚未初始化")
        return path.read_text(encoding="utf-8")

    def _certificate_fingerprint_pem(self, certificate: str) -> str:
        with tempfile.TemporaryDirectory(dir=self.module) as temporary:
            path = Path(temporary) / "certificate.crt"
            path.write_text(certificate, encoding="utf-8")
            result = self._openssl(["x509", "-in", str(path), "-noout", "-fingerprint", "-sha256"])
        value = result.stdout.strip().split("=", 1)[-1].replace(":", "").lower()
        if not re.fullmatch(r"[0-9a-f]{64}", value):
            raise ClusterError("联邦证书指纹无效")
        return value

    def validate_federation_certificates(self, node_id: str, root_certificate: str,
                                         identity_certificate: str) -> tuple[str, str]:
        if not re.fullmatch(r"[0-9a-f]{32}", node_id):
            raise ClusterError("联邦成员 node_id 无效")
        if "BEGIN CERTIFICATE" not in root_certificate or "BEGIN CERTIFICATE" not in identity_certificate:
            raise ClusterError("联邦成员证书不完整")
        with tempfile.TemporaryDirectory(dir=self.module) as temporary:
            root, identity = Path(temporary) / "root.crt", Path(temporary) / "identity.crt"
            root.write_text(root_certificate, encoding="utf-8")
            identity.write_text(identity_certificate, encoding="utf-8")
            root_text = self._openssl(["x509", "-in", str(root), "-noout", "-text"]).stdout
            if not re.search(r"Basic Constraints:.*?CA:TRUE", root_text, re.DOTALL | re.IGNORECASE):
                raise ClusterError("联邦根证书不是 CA 证书")
            verify = self._openssl(["verify", "-CAfile", str(root), str(identity)], check=False)
            if verify.returncode:
                raise ClusterError("联邦身份证书不受所提供根证书签发")
            subject = self._openssl(["x509", "-in", str(identity), "-noout", "-subject", "-nameopt", "RFC2253"]).stdout.strip()
            match = re.search(r"(?:^|,)CN=([^,]+)", subject.removeprefix("subject="))
            if not match or match.group(1) != node_id:
                raise ClusterError("联邦身份证书 CN 与 node_id 不一致")
            purpose = self._openssl(["x509", "-in", str(identity), "-noout", "-purpose"]).stdout
            if not re.search(r"SSL client\s*:\s*Yes", purpose, re.IGNORECASE) or not re.search(r"SSL server\s*:\s*Yes", purpose, re.IGNORECASE):
                raise ClusterError("联邦身份证书必须同时支持客户端和服务端 TLS")
        return self._certificate_fingerprint_pem(root_certificate), self._certificate_fingerprint_pem(identity_certificate)

    def register_federation_key(self, node_id: str, root_certificate: str, identity_certificate: str = "") -> None:
        root_fingerprint, identity_fingerprint = self.validate_federation_certificates(
            node_id, root_certificate, identity_certificate
        )
        existing = self.db.connection.execute("SELECT * FROM federation_keys WHERE node_id=?", (node_id,)).fetchone()
        if existing and str(existing["root_fingerprint"] or self._certificate_fingerprint_pem(str(existing["root_certificate"]))) != root_fingerprint:
            raise ClusterError("活动 node_id 的根证书不可替换；请使用新 node_id 重新加入")
        if existing and str(existing["identity_fingerprint"] or self._certificate_fingerprint_pem(str(existing["identity_certificate"]))) != identity_fingerprint:
            raise ClusterError("活动 node_id 的身份证书不可替换；请使用新 node_id 重新加入")
        now = utc_now()
        with self.db.connection:
            self.db.connection.execute(
                "INSERT INTO federation_keys(node_id,root_certificate,identity_certificate,root_fingerprint,identity_fingerprint,created_at,updated_at) VALUES(?,?,?,?,?,?,?) "
                "ON CONFLICT(node_id) DO UPDATE SET updated_at=excluded.updated_at",
                (node_id, root_certificate, identity_certificate, root_fingerprint, identity_fingerprint, now, now),
            )

    def federation_member_payload(self, status: dict[str, Any], root_certificate: str | None = None,
                                  identity_certificate: str | None = None, legacy_number: bool = False) -> dict[str, Any]:
        return {"status": status, "root_certificate": root_certificate or self.federation_root_certificate(),
                "identity_certificate": identity_certificate or self.federation_identity_certificate(),
                "server_number": int(status.get("server_number", self.load_config().get("server_number", 1))),
                "legacy_number": bool(legacy_number)}

    def publish_local_node_metadata(self) -> dict[str, Any]:
        if not self.is_federation():
            raise ClusterError("当前不是联邦模式")
        status = self.local_status()
        node_id = str(status.get("node_id", ""))
        if not re.fullmatch(r"[0-9a-f]{32}", node_id):
            raise ClusterError("本机联邦身份无效")
        self.upsert_node(status, role="federation")
        return self.create_event(
            "node.metadata", f"node:{node_id}", {"node_id": node_id, "status": status}
        )

    def endpoint_status(self, actual_ip: str = "") -> dict[str, Any]:
        config = self.load_config()
        advertised = str(config.get("public_host", ""))
        pending_text = self.db.setting("federation.endpoint.pending", "{}")
        success_text = self.db.setting("federation.endpoint.success", "{}")
        try:
            pending = json.loads(pending_text)
        except json.JSONDecodeError:
            pending = {}
        try:
            successful = json.loads(success_text)
        except json.JSONDecodeError:
            successful = {}
        return {
            "actual_ip": actual_ip or self.db.setting("federation.endpoint.actual", ""),
            "advertised_ip": advertised,
            "synced": not bool(pending),
            "pending": pending if isinstance(pending, dict) else {},
            "successful": successful if isinstance(successful, dict) else {},
            "last_checked": int(self.db.setting("federation.endpoint.last_checked", "0") or 0),
            "changed_at": int(self.db.setting("federation.endpoint.changed_at", "0") or 0),
        }

    def mark_endpoint_synced(self, node_id: str) -> None:
        try:
            pending = json.loads(self.db.setting("federation.endpoint.pending", "{}"))
        except json.JSONDecodeError:
            pending = {}
        if isinstance(pending, dict) and node_id in pending:
            pending.pop(node_id, None)
            self.db.set_setting("federation.endpoint.pending", json_dumps(pending))
        try:
            successful = json.loads(self.db.setting("federation.endpoint.success", "{}"))
        except json.JSONDecodeError:
            successful = {}
        if not isinstance(successful, dict):
            successful = {}
        successful[node_id] = utc_now()
        self.db.set_setting("federation.endpoint.success", json_dumps(successful))

    def reconcile_public_endpoint(self, public_ip: str,
                                  public_hosts: Iterable[Any] | None = None) -> dict[str, Any]:
        if not self.is_federation():
            raise ClusterError("当前不是联邦模式")
        new_host = normalize_public_ip(public_ip)
        config = self.load_config()
        old_host = str(config.get("public_host", ""))
        old_hosts = order_public_hosts(
            config.get("public_hosts", []) if isinstance(config.get("public_hosts"), list) else [], old_host
        )
        new_hosts = order_public_hosts(public_hosts or [], new_host)
        new_host = new_hosts[0]
        with contextlib.suppress(ValueError, ClusterError):
            if normalize_public_ip(old_host) == new_host and old_hosts == new_hosts:
                return {"changed": False, "old_host": old_host, "new_host": new_host,
                        "old_hosts": old_hosts, "new_hosts": new_hosts, "event": None}
        try:
            ipaddress.ip_address(old_host.strip().strip("[]"))
        except ValueError:
            raise ClusterError("联邦当前公布的是域名，不会自动改为 IP")
        original = json.loads(json.dumps(config))
        original_status = self.local_status()
        config["public_host"] = new_host
        config["public_hosts"] = new_hosts
        try:
            self.save_config(config)
            event = self.publish_local_node_metadata()
        except Exception:
            self.save_config(original)
            self.upsert_node(original_status, role="federation")
            raise
        now = utc_now()
        self.db.set_setting("federation.endpoint.changed_at", str(now))
        self.db.audit("federation.endpoint.changed", str(config.get("node_id", "")),
                      f"{old_host}->{new_host}")
        return {"changed": True, "old_host": old_host, "new_host": new_host,
                "old_hosts": old_hosts, "new_hosts": new_hosts, "event": event}

    def _sign_federation(self, content: bytes) -> str:
        key = self.pki / "federation-root.key"
        if not key.is_file():
            raise ClusterError("联邦签名私钥不存在")
        with tempfile.TemporaryDirectory(dir=self.module) as temporary:
            source, signature = Path(temporary) / "content", Path(temporary) / "signature"
            source.write_bytes(content)
            self._openssl(["dgst", "-sha256", "-sign", str(key), "-out", str(signature), str(source)])
            return base64.b64encode(signature.read_bytes()).decode("ascii")

    def _verify_federation_signature(self, certificate: str, content: bytes, signature: str) -> bool:
        try:
            raw_signature = base64.b64decode(signature.encode("ascii"), validate=True)
        except (ValueError, binascii.Error):
            return False
        with tempfile.TemporaryDirectory(dir=self.module) as temporary:
            cert, public, source, sig = (Path(temporary) / name for name in ("root.crt", "root.pub", "content", "signature"))
            cert.write_text(certificate, encoding="utf-8")
            source.write_bytes(content)
            sig.write_bytes(raw_signature)
            try:
                self._openssl(["x509", "-in", str(cert), "-pubkey", "-noout", "-out", str(public)])
                return self._openssl(["dgst", "-sha256", "-verify", str(public), "-signature", str(sig), str(source)], check=False).returncode == 0
            except ClusterError:
                return False

    def federation_lamport(self) -> int:
        return int(self.db.setting("federation.lamport", "0") or 0)

    @staticmethod
    def _federation_user_key(owner_id: str, source_key: str) -> str:
        if not re.fullmatch(r"[0-9a-f]{32}", owner_id) or not re.fullmatch(r"[0-9]{1,18}", source_key):
            raise ClusterError("federation user key is invalid")
        return f"{owner_id}:user:{source_key}"

    @staticmethod
    def _federation_agent_user_key(user_key: str) -> str:
        value = int.from_bytes(hashlib.sha256(user_key.encode("utf-8")).digest()[:7], "big")
        return str(max(1, value))

    def _validate_federation_user_event(self, event_type: str, entity_key: str,
                                        payload: dict[str, Any]) -> None:
        if len(json_dumps(payload).encode("utf-8")) > 64 * 1024:
            raise ClusterError("federation user event is too large")
        owner_id = str(payload.get("owner_id", ""))
        user_key = str(payload.get("user_key", ""))
        if not re.fullmatch(r"[0-9a-f]{32}", owner_id) or not re.fullmatch(
                r"[0-9a-f]{32}:user:[0-9]{1,18}", user_key):
            raise ClusterError("federation user identity is invalid")
        if not user_key.startswith(owner_id + ":user:"):
            raise ClusterError("federation user owner does not match its stable key")
        if event_type in {"user.upsert", "user.delete"}:
            if entity_key != "user:" + user_key:
                raise ClusterError("federation user entity key is invalid")
            if event_type == "user.delete":
                return
            name = str(payload.get("name", "")).strip()
            if not name or len(name) > 128:
                raise ClusterError("federation user name is invalid")
            try:
                quotas = [int(payload.get(field, 0)) for field in ("lifetime_quota", "monthly_quota")]
                reset_day = int(payload.get("reset_day", 1))
                max_devices = int(payload.get("max_devices", 1))
            except (TypeError, ValueError) as exc:
                raise ClusterError("federation user numeric policy is invalid") from exc
            if any(value < 0 or value > 2 ** 63 - 1 for value in quotas):
                raise ClusterError("federation user quota is invalid")
            if reset_day not in range(1, 29) or max_devices not in range(1, FEDERATION_DEVICE_MAX + 1):
                raise ClusterError("federation user reset day or device limit is invalid")
            expires_at = payload.get("expires_at")
            if expires_at is not None and (not isinstance(expires_at, int) or expires_at < 0):
                raise ClusterError("federation user expiry is invalid")
            return
        if event_type == "authorization.upsert":
            if entity_key != "authorization:" + user_key:
                raise ClusterError("federation authorization entity key is invalid")
            nodes = payload.get("nodes")
            permissions = payload.get("permissions")
            if not isinstance(nodes, list) or len(nodes) > 256 or any(
                    not re.fullmatch(r"[0-9a-f]{32}", str(node)) for node in nodes):
                raise ClusterError("federation authorization node list is invalid")
            if len(nodes) != len(set(str(node) for node in nodes)):
                raise ClusterError("federation authorization node list contains duplicates")
            if not isinstance(permissions, dict) or any(
                    key not in FEDERATION_PROTOCOLS or not isinstance(value, bool)
                    for key, value in permissions.items()):
                raise ClusterError("federation protocol authorization is invalid")
            if not isinstance(payload.get("enabled", True), bool) or not isinstance(payload.get("deleted", False), bool):
                raise ClusterError("federation authorization state is invalid")
            return
        device_key = str(payload.get("device_key", ""))
        if not re.fullmatch(re.escape(user_key) + r":device:[0-9a-f-]{36}", device_key):
            raise ClusterError("federation device key is invalid")
        try:
            stable_device_uuid = str(uuid.UUID(device_key.rsplit(":device:", 1)[1]))
        except ValueError as exc:
            raise ClusterError("federation stable device UUID is invalid") from exc
        if not device_key.endswith(":device:" + stable_device_uuid):
            raise ClusterError("federation stable device UUID is not canonical")
        if event_type in {"device.upsert", "device.delete"}:
            if entity_key != "device:" + device_key:
                raise ClusterError("federation device entity key is invalid")
            if event_type == "device.delete":
                return
            try:
                device_uuid = str(uuid.UUID(str(payload.get("uuid", ""))))
            except ValueError as exc:
                raise ClusterError("federation device UUID is invalid") from exc
            if device_uuid != stable_device_uuid:
                raise ClusterError("federation device UUID does not match its stable key")
            name = str(payload.get("name", "")).strip()
            password, ss_password = str(payload.get("password", "")), str(payload.get("ss_password", ""))
            if not name or len(name) > 128 or not (8 <= len(password) <= 256) or not (8 <= len(ss_password) <= 256):
                raise ClusterError("federation device credentials are invalid")
            if not isinstance(payload.get("enabled", True), bool):
                raise ClusterError("federation device state is invalid")
            return
        if event_type in {"token.upsert", "token.delete"}:
            if entity_key != "token:" + device_key:
                raise ClusterError("federation token entity key is invalid")
            if event_type == "token.delete":
                return
            token = str(payload.get("token", ""))
            if not re.fullmatch(r"[A-Za-z0-9_-]{16,128}", token) or not isinstance(payload.get("enabled", True), bool):
                raise ClusterError("federation subscription token is invalid")
            return
        raise ClusterError("unsupported federation user event")

    def _validate_event_payload(self, event_type: str, entity_key: str, payload: dict[str, Any]) -> None:
        if event_type == "profile.upsert":
            name = safe_label(str(payload.get("name", "")))
            token = str(payload.get("token", ""))
            selector = str(payload.get("selector", ""))
            profile_key = str(payload.get("profile_key", ""))
            if not name or len(selector) > 4096 or not selector \
                    or not re.fullmatch(r"[A-Za-z0-9_-]{16,128}", token) \
                    or not profile_key or safe_slug(profile_key) != profile_key \
                    or entity_key != self.federation_profile_entity_key(selector, profile_key):
                raise ClusterError("federation profile event is invalid")
            return
        if event_type in FEDERATION_USER_EVENT_TYPES:
            self._validate_federation_user_event(event_type, entity_key, payload)

    def _create_event_if_changed(self, event_type: str, entity_key: str,
                                 payload: dict[str, Any]) -> dict[str, Any] | None:
        current = self.db.connection.execute(
            "SELECT type,payload,deleted FROM federation_entities WHERE entity_key=?", (entity_key,)
        ).fetchone()
        deleted = event_type in {"user.delete", "device.delete", "token.delete"}
        if current and bool(current["deleted"]) and not deleted:
            return None
        if current and str(current["type"]) == event_type and bool(current["deleted"]) == deleted \
                and hmac.compare_digest(str(current["payload"]).encode("utf-8"),
                                        json_dumps(payload).encode("utf-8")):
            return None
        return self.create_event(event_type, entity_key, payload)

    def publish_local_user_events(self) -> dict[str, Any]:
        if not self.is_federation():
            raise ClusterError("federation mode is not enabled")
        database = self.root / "modules" / "multiuser" / "data" / "lun.db"
        if not database.is_file():
            return {"users": 0, "events": 0, "skipped": True}
        owner_id = str(self.load_config().get("node_id", ""))
        bundle = export_master_users(self)
        users = bundle.get("users")
        if int(bundle.get("schema_version", 0)) != 1 or not isinstance(users, list) \
                or len(users) > FEDERATION_USER_MAX:
            raise ClusterError("local multi-user export is invalid")
        current_entities: set[str] = set()
        events: list[dict[str, Any]] = []
        for raw in users:
            if not isinstance(raw, dict):
                raise ClusterError("local multi-user export contains a non-object user")
            source_key = str(raw.get("key", ""))
            user_key = self._federation_user_key(owner_id, source_key)
            user_entity = "user:" + user_key
            user_payload = {
                "owner_id": owner_id, "user_key": user_key, "source_key": source_key,
                "name": str(raw.get("name", "")).strip(),
                "manual_disabled": bool(raw.get("manual_disabled", False)),
                "lifetime_quota": int(raw.get("lifetime_quota", 0)),
                "monthly_quota": int(raw.get("monthly_quota", 0)),
                "reset_day": int(raw.get("reset_day", 1)), "expires_at": raw.get("expires_at"),
                "max_devices": int(raw.get("max_devices", 1)),
            }
            self._validate_federation_user_event("user.upsert", user_entity, user_payload)
            current_entities.add(user_entity)
            created = self._create_event_if_changed("user.upsert", user_entity, user_payload)
            if created:
                events.append(created)
            assigned = [str(row[0]) for row in self.db.connection.execute(
                "SELECT node_id FROM user_nodes WHERE user_id=? ORDER BY node_id", (int(source_key),)
            ) if re.fullmatch(r"[0-9a-f]{32}", str(row[0]))]
            permissions = raw.get("permissions") if isinstance(raw.get("permissions"), dict) else {}
            authorization_entity = "authorization:" + user_key
            authorization_payload = {
                "owner_id": owner_id, "user_key": user_key, "nodes": list(dict.fromkeys(assigned)),
                "permissions": {key: bool(value) for key, value in permissions.items() if key in FEDERATION_PROTOCOLS},
                "enabled": not bool(raw.get("manual_disabled", False)), "deleted": False,
            }
            self._validate_federation_user_event("authorization.upsert", authorization_entity, authorization_payload)
            current_entities.add(authorization_entity)
            created = self._create_event_if_changed("authorization.upsert", authorization_entity, authorization_payload)
            if created:
                events.append(created)
            devices = raw.get("devices")
            if not isinstance(devices, list) or len(devices) > FEDERATION_DEVICE_MAX:
                raise ClusterError("local multi-user device list is invalid")
            for raw_device in devices:
                if not isinstance(raw_device, dict):
                    raise ClusterError("local multi-user export contains a non-object device")
                try:
                    device_uuid = str(uuid.UUID(str(raw_device.get("uuid", ""))))
                except ValueError as exc:
                    raise ClusterError("local multi-user device UUID is invalid") from exc
                device_key = f"{user_key}:device:{device_uuid}"
                device_entity = "device:" + device_key
                device_payload = {
                    "owner_id": owner_id, "user_key": user_key, "device_key": device_key,
                    "name": str(raw_device.get("name", "")).strip(), "uuid": device_uuid,
                    "password": str(raw_device.get("password", "")),
                    "ss_password": str(raw_device.get("ss_password", "")),
                    "enabled": bool(raw_device.get("enabled", True)),
                }
                self._validate_federation_user_event("device.upsert", device_entity, device_payload)
                current_entities.add(device_entity)
                created = self._create_event_if_changed("device.upsert", device_entity, device_payload)
                if created:
                    events.append(created)
                token_entity = "token:" + device_key
                token_payload = {
                    "owner_id": owner_id, "user_key": user_key, "device_key": device_key,
                    "token": str(raw_device.get("token", "")),
                    "enabled": bool(raw_device.get("enabled", True)),
                }
                self._validate_federation_user_event("token.upsert", token_entity, token_payload)
                current_entities.add(token_entity)
                created = self._create_event_if_changed("token.upsert", token_entity, token_payload)
                if created:
                    events.append(created)
        owned: dict[str, tuple[str, dict[str, Any]]] = {}
        for row in self.db.connection.execute(
                "SELECT entity_key,type,payload FROM federation_entities WHERE type IN "
                "('user.upsert','device.upsert','authorization.upsert','token.upsert')"):
            try:
                payload = json.loads(str(row["payload"]))
            except json.JSONDecodeError:
                continue
            if isinstance(payload, dict) and payload.get("owner_id") == owner_id:
                owned[str(row["entity_key"])] = (str(row["type"]), payload)
        for entity_key, (event_type, payload) in sorted(owned.items()):
            if entity_key in current_entities:
                continue
            common = {"owner_id": owner_id, "user_key": str(payload.get("user_key", ""))}
            if event_type == "user.upsert":
                created = self._create_event_if_changed("user.delete", entity_key, common)
            elif event_type == "device.upsert":
                common["device_key"] = str(payload.get("device_key", ""))
                created = self._create_event_if_changed("device.delete", entity_key, common)
            elif event_type == "token.upsert":
                common["device_key"] = str(payload.get("device_key", ""))
                created = self._create_event_if_changed("token.delete", entity_key, common)
            else:
                common.update({"nodes": [], "permissions": {}, "enabled": False, "deleted": True})
                created = self._create_event_if_changed("authorization.upsert", entity_key, common)
            if created:
                events.append(created)
        self.db.audit("federation.users.publish", owner_id, f"users={len(users)} events={len(events)}")
        return {"users": len(users), "events": len(events)}

    def _apply_federation_user_bundle(self, bundle: dict[str, Any]) -> dict[str, Any]:
        database = self.root / "modules" / "multiuser" / "data" / "lun.db"
        if not bundle.get("users") and not database.exists():
            return {"users": 0, "devices": 0, "skipped": True}
        agent = _multiuser_agent_path(self)
        origin = str(self.load_config().get("cluster_id", ""))
        if not re.fullmatch(r"[0-9a-f]{32}", origin):
            raise ClusterError("federation cluster identity is invalid")
        with tempfile.NamedTemporaryFile("w", encoding="utf-8", dir=str(self.module), delete=False) as handle:
            json.dump(bundle, handle, ensure_ascii=False)
            temporary = Path(handle.name)
        os.chmod(temporary, 0o600)
        try:
            imported = self._run(
                [str(agent), "--root", str(self.root), "--json", "cluster-import", "--path", str(temporary),
                 "--origin", origin], timeout=120, check=False,
            )
        finally:
            temporary.unlink(missing_ok=True)
        if imported.returncode:
            raise ClusterError((imported.stderr or imported.stdout or "federation user import failed")[-2000:])
        applied = self._run([str(agent), "--root", str(self.root), "--json", "apply"], timeout=300, check=False)
        if applied.returncode:
            raise ClusterError((applied.stderr or applied.stdout or "federation user apply failed")[-2000:])
        try:
            result = json.loads(imported.stdout)
        except json.JSONDecodeError:
            result = {"users": len(bundle.get("users", []))}
        return result if isinstance(result, dict) else {"users": len(bundle.get("users", []))}

    def apply_federation_users(self, *, refresh: bool = True) -> dict[str, Any]:
        if not self.is_federation():
            return {"users": 0, "profiles": 0, "skipped": True}
        entities: dict[str, tuple[str, dict[str, Any], bool]] = {}
        for row in self.db.connection.execute(
                "SELECT entity_key,type,payload,deleted FROM federation_entities WHERE type IN "
                "('user.upsert','user.delete','device.upsert','device.delete','authorization.upsert','token.upsert','token.delete')"):
            try:
                payload = json.loads(str(row["payload"]))
            except json.JSONDecodeError:
                continue
            if isinstance(payload, dict):
                entities[str(row["entity_key"])] = (str(row["type"]), payload, bool(row["deleted"]))
        local_id = str(self.load_config().get("node_id", ""))
        bundle_users: list[dict[str, Any]] = []
        active_profile_ids: set[int] = set()
        seen_agent_keys: dict[str, str] = {}
        devices_by_user: dict[str, list[dict[str, Any]]] = {}
        tokens_by_device: dict[str, tuple[str, dict[str, Any], bool]] = {}
        for entity_key, (event_type, payload, deleted) in entities.items():
            if entity_key.startswith("device:") and event_type == "device.upsert" and not deleted:
                devices_by_user.setdefault(str(payload.get("user_key", "")), []).append(payload)
            elif entity_key.startswith("token:"):
                tokens_by_device[str(payload.get("device_key", ""))] = (event_type, payload, deleted)
        seen_credentials: set[str] = set()
        for entity_key, (event_type, user, deleted) in sorted(entities.items()):
            if not entity_key.startswith("user:") or event_type != "user.upsert" or deleted:
                continue
            user_key = str(user.get("user_key", ""))
            authorization = entities.get("authorization:" + user_key)
            if not authorization or authorization[2] or authorization[0] != "authorization.upsert":
                nodes: list[str] = []
                permissions: dict[str, bool] = {}
                authorized = False
            else:
                auth = authorization[1]
                nodes = [str(value) for value in auth.get("nodes", [])]
                permissions = {str(key): bool(value) for key, value in auth.get("permissions", {}).items()}
                authorized = bool(auth.get("enabled", True)) and not bool(auth.get("deleted", False))
            authorized = authorized and not bool(user.get("manual_disabled", False))
            agent_key = self._federation_agent_user_key(user_key)
            collision = seen_agent_keys.get(agent_key)
            if collision and collision != user_key:
                raise ClusterError("federation user key hash collision")
            seen_agent_keys[agent_key] = user_key
            devices: list[dict[str, Any]] = []
            user_devices = sorted(devices_by_user.get(user_key, []), key=lambda item: str(item.get("device_key", "")))
            if len(user_devices) > FEDERATION_DEVICE_MAX:
                raise ClusterError("federation user has too many active devices")
            for device in user_devices:
                token_row = tokens_by_device.get(str(device.get("device_key", "")))
                if not token_row or token_row[0] != "token.upsert" or token_row[2]:
                    continue
                token_payload = token_row[1]
                token = str(token_payload.get("token", ""))
                for credential in (str(device.get("uuid", "")), token):
                    if credential in seen_credentials:
                        raise ClusterError("federation device UUID or token is duplicated")
                    seen_credentials.add(credential)
                enabled = bool(device.get("enabled", True)) and bool(token_payload.get("enabled", True))
                devices.append({
                    "key": str(device.get("uuid", "")),
                    "name": str(device.get("name", "")), "uuid": str(device.get("uuid", "")),
                    "password": str(device.get("password", "")), "ss_password": str(device.get("ss_password", "")),
                    "token": token, "enabled": enabled,
                })
                if authorized and enabled and nodes:
                    profile_name = safe_label(f"用户 {agent_key} {user.get('name', '')} / {device.get('name', '')}")
                    profile = self.ensure_profile(profile_name, "nodes:" + ",".join(nodes), token, token)
                    active_profile_ids.add(int(profile["id"]))
            if authorized and local_id in nodes and user.get("owner_id") != local_id:
                bundle_users.append({
                    "key": agent_key, "name": str(user.get("name", "")),
                    "manual_disabled": False, "lifetime_quota": int(user.get("lifetime_quota", 0)),
                    "monthly_quota": int(user.get("monthly_quota", 0)), "reset_day": int(user.get("reset_day", 1)),
                    "expires_at": user.get("expires_at"), "max_devices": max(int(user.get("max_devices", 1)), len(devices)),
                    "devices": devices, "permissions": permissions,
                })
        try:
            old_values = json.loads(self.db.setting("federation.user_profile_ids", "[]") or "[]")
        except json.JSONDecodeError:
            old_values = []
        old_profile_ids = {int(value) for value in old_values if isinstance(value, int) or str(value).isdigit()}
        with self.db.connection:
            for profile_id in old_profile_ids - active_profile_ids:
                self.db.connection.execute("UPDATE profiles SET enabled=0,updated_at=? WHERE id=?", (utc_now(), profile_id))
        self.db.set_setting("federation.user_profile_ids", json_dumps(sorted(active_profile_ids)))
        try:
            imported = self._apply_federation_user_bundle({"schema_version": 1, "users": bundle_users})
            self.db.set_setting("federation.users.pending", "0")
        except ClusterError:
            self.db.set_setting("federation.users.pending", "1")
            raise
        refreshed = len(self.refresh_profiles()) if refresh else 0
        self.db.audit("federation.users.apply", local_id,
                      f"users={len(bundle_users)} profiles={len(active_profile_ids)}")
        return {"users": len(bundle_users), "profiles": len(active_profile_ids),
                "refreshed": refreshed, "import": imported}

    def create_event(self, event_type: str, entity_key: str, payload: dict[str, Any], *, created_at: int | None = None) -> dict[str, Any]:
        self._validate_event_payload(event_type, entity_key, payload)
        if not self.is_federation() or event_type not in FEDERATION_EVENT_TYPES:
            raise ClusterError("联邦事件类型或模式无效")
        config = self.load_config()
        author_id = str(config["node_id"])
        head = self.db.connection.execute("SELECT * FROM federation_heads WHERE author_id=?", (author_id,)).fetchone()
        event = {"author_id": author_id, "author_seq": int(head["author_seq"] if head else 0) + 1,
                 "prev_hash": str(head["event_hash"] if head else ""), "lamport": max(self.federation_lamport(), int(head["lamport"] if head else 0)) + 1,
                 "type": event_type, "entity_key": safe_label(entity_key, 160), "payload": json_dumps(payload),
                 "created_at": int(created_at or utc_now())}
        event["signature"] = self._sign_federation(canonical_event_fields(event))
        event["event_id"] = event_hash(event)
        self.ingest_event(event)
        return event

    def _event_certificate(self, author_id: str, author_seq: int | None = None) -> str:
        row = self.db.connection.execute("SELECT * FROM federation_keys WHERE node_id=?", (author_id,)).fetchone()
        if not row:
            raise ClusterError("事件作者未受信任")
        if int(row["revoked_at"]):
            cutoff = int(row["revoked_after_seq"])
            if author_seq is None or cutoff < 0 or int(author_seq) > cutoff:
                raise ClusterError("事件位于作者撤销边界之后")
        return str(row["root_certificate"])

    @staticmethod
    def _event_sort_key(event: dict[str, Any]) -> tuple[int, str, str]:
        return int(event["lamport"]), str(event["author_id"]), str(event["event_id"])

    def _record_number_claim(self, event: dict[str, Any], member_id: str, payload: dict[str, Any]) -> None:
        requested = max(1, int(payload.get("server_number", 1) or 1))
        with self.db.connection:
            self.db.connection.execute(
                "INSERT INTO federation_number_claims(node_id,requested_number,fixed,lamport,author_id,event_id) VALUES(?,?,?,?,?,?) "
                "ON CONFLICT(node_id) DO UPDATE SET requested_number=excluded.requested_number,fixed=MAX(federation_number_claims.fixed,excluded.fixed),lamport=excluded.lamport,author_id=excluded.author_id,event_id=excluded.event_id",
                (member_id, requested, int(bool(payload.get("legacy_number"))), int(event["lamport"]), event["author_id"], event["event_id"]),
            )
        self._resolve_federation_numbers()

    def _resolve_federation_numbers(self) -> None:
        claims = self.db.connection.execute(
            "SELECT * FROM federation_number_claims ORDER BY fixed DESC,lamport,author_id,event_id,node_id"
        ).fetchall()
        claim_ids = {str(row["node_id"]) for row in claims}
        used = {int(row["server_number"]) for row in self.db.connection.execute(
            "SELECT node_id,server_number FROM node_number_history"
        ) if str(row["node_id"]) not in claim_ids and int(row["server_number"]) > 0}
        assignments: dict[str, int] = {}
        for row in claims:
            requested = int(row["requested_number"])
            number = requested
            while number in used:
                number += 1
            assignments[str(row["node_id"])] = number
            used.add(number)
        with self.db.connection:
            for index, node_id in enumerate(sorted(claim_ids), 1):
                self.db.connection.execute("UPDATE node_number_history SET server_number=? WHERE node_id=?", (-index, node_id))
            for node_id, number in assignments.items():
                self.db.connection.execute(
                    "INSERT INTO node_number_history(node_id,server_number,allocated_at) VALUES(?,?,?) "
                    "ON CONFLICT(node_id) DO UPDATE SET server_number=excluded.server_number",
                    (node_id, number, utc_now()),
                )
                self.db.connection.execute("UPDATE nodes SET server_number=?,updated_at=? WHERE id=?", (number, utc_now(), node_id))
                self.db.connection.execute("UPDATE federation_number_claims SET assigned_number=? WHERE node_id=?", (number, node_id))

    def ingest_event(self, event: dict[str, Any]) -> bool:
        required = {"event_id", "author_id", "author_seq", "prev_hash", "lamport", "type", "entity_key", "payload", "created_at", "signature"}
        if set(event) < required or event.get("type") not in FEDERATION_EVENT_TYPES:
            raise ClusterError("联邦事件字段无效")
        if not re.fullmatch(r"[0-9a-f]{32}", str(event["author_id"])) or int(event["author_seq"]) < 1:
            raise ClusterError("联邦事件作者或序号无效")
        if not isinstance(event["payload"], str) or event_hash(event) != event["event_id"]:
            raise ClusterError("联邦事件哈希无效")
        try:
            payload = json.loads(event["payload"])
        except json.JSONDecodeError as exc:
            raise ClusterError("联邦事件载荷无效") from exc
        if isinstance(payload, dict):
            self._validate_event_payload(str(event["type"]), str(event["entity_key"]), payload)
        if event["type"] == "node.metadata" and isinstance(payload, dict) \
                and isinstance(payload.get("status"), dict):
            node_id = str(payload.get("node_id", ""))
            if event["entity_key"] != f"node:{node_id}" or event["author_id"] != node_id:
                raise ClusterError("节点元数据必须由节点自身签名")
        if not isinstance(payload, dict) or not self._verify_federation_signature(
            self._event_certificate(str(event["author_id"]), int(event["author_seq"])),
            canonical_event_fields(event), str(event["signature"])
        ):
            raise ClusterError("联邦事件签名无效")
        existing = self.db.connection.execute("SELECT event_hash FROM federation_events WHERE event_id=?", (event["event_id"],)).fetchone()
        if existing:
            return False
        head = self.db.connection.execute("SELECT * FROM federation_heads WHERE author_id=?", (event["author_id"],)).fetchone()
        if int(event["author_seq"]) != int(head["author_seq"] if head else 0) + 1 or str(event["prev_hash"]) != str(head["event_hash"] if head else ""):
            raise ClusterError("联邦事件链不连续")
        with self.db.connection:
            self.db.connection.execute(
                "INSERT INTO federation_events(event_id,author_id,author_seq,prev_hash,lamport,type,entity_key,payload,created_at,signature,event_hash) VALUES(?,?,?,?,?,?,?,?,?,?,?)",
                tuple(event[key] for key in ("event_id", "author_id", "author_seq", "prev_hash", "lamport", "type", "entity_key", "payload", "created_at", "signature")) + (event["event_id"],),
            )
            self.db.connection.execute("INSERT INTO federation_heads(author_id,author_seq,event_hash,lamport) VALUES(?,?,?,?) ON CONFLICT(author_id) DO UPDATE SET author_seq=excluded.author_seq,event_hash=excluded.event_hash,lamport=excluded.lamport", (event["author_id"], event["author_seq"], event["event_id"], event["lamport"]))
            self.db.set_setting("federation.lamport", max(self.federation_lamport(), int(event["lamport"])))
        self._apply_federation_entity(event, payload)
        return True

    def _apply_federation_entity(self, event: dict[str, Any], payload: dict[str, Any]) -> None:
        current = self.db.connection.execute("SELECT * FROM federation_entities WHERE entity_key=?", (event["entity_key"],)).fetchone()
        tombstone_types = {"member.revoke", "revocation.proof", "user.delete", "device.delete", "token.delete"}
        incoming_tombstone = event["type"] in tombstone_types
        permanent_prefix = str(event["entity_key"]).split(":", 1)[0] in {"member", "user", "device", "token"}
        if event["type"] in {"member.revoke", "revocation.proof"}:
            node_id = str(payload.get("node_id", str(event["entity_key"]).removeprefix("member:")))
            cutoff = max(0, int(payload.get("revoked_after_seq", 0)))
            revoked_time = max(1, int(event["created_at"]))
            with self.db.connection:
                self.db.connection.execute(
                    "UPDATE federation_keys SET revoked_at=CASE WHEN revoked_at=0 THEN ? ELSE MIN(revoked_at,?) END,"
                    "revoked_after_seq=CASE WHEN revoked_after_seq<0 THEN ? ELSE MIN(revoked_after_seq,?) END,"
                    "revocation_event_id=CASE WHEN revocation_event_id='' OR ?<revocation_event_id THEN ? ELSE revocation_event_id END,updated_at=? WHERE node_id=?",
                    (revoked_time, revoked_time, cutoff, cutoff,
                     event["event_id"], event["event_id"], utc_now(), node_id),
                )
                self.db.connection.execute("UPDATE nodes SET state='revoked',updated_at=? WHERE id=?", (utc_now(), node_id))
        if current and int(current["deleted"]) and permanent_prefix:
            if not incoming_tombstone or self._event_sort_key(event) <= (
                    int(current["lamport"]), str(current["author_id"]), str(current["event_id"])):
                return
        elif current and not incoming_tombstone and self._event_sort_key(event) <= (
                int(current["lamport"]), str(current["author_id"]), str(current["event_id"])):
            return
        deleted = int(incoming_tombstone)
        with self.db.connection:
            self.db.connection.execute(
                "INSERT INTO federation_entities(entity_key,type,payload,deleted,lamport,author_id,event_id,updated_at) VALUES(?,?,?,?,?,?,?,?) "
                "ON CONFLICT(entity_key) DO UPDATE SET type=excluded.type,payload=excluded.payload,deleted=excluded.deleted,lamport=excluded.lamport,author_id=excluded.author_id,event_id=excluded.event_id,updated_at=excluded.updated_at",
                (event["entity_key"], event["type"], event["payload"], deleted, event["lamport"], event["author_id"], event["event_id"], utc_now()),
            )
        if event["type"] == "member.upsert":
            status = payload.get("status") if isinstance(payload.get("status"), dict) else {}
            member_id = str(status.get("node_id", ""))
            if re.fullmatch(r"[0-9a-f]{32}", member_id):
                root = str(payload.get("root_certificate", ""))
                if root:
                    self.register_federation_key(member_id, root, str(payload.get("identity_certificate", "")))
                requested = int(payload.get("server_number", 0) or 0)
                self.upsert_node({**status, "server_number": requested or status.get("server_number", 0)}, role="federation")
                self._record_number_claim(event, member_id, payload)
        elif event["type"] == "node.metadata":
            status = payload.get("status") if isinstance(payload.get("status"), dict) else {}
            node_id = str(payload.get("node_id", ""))
            if status.get("node_id") == node_id and re.fullmatch(r"[0-9a-f]{32}", node_id):
                self.upsert_node(status, role="federation")
        elif event["type"] in {"member.revoke", "revocation.proof"}:
            pass
        elif event["type"] == "usage.absolute":
            self.record_usage(str(payload.get("node_id", event["author_id"])), str(payload.get("device_uuid", "")),
                              str(payload.get("epoch", "")), int(payload.get("uplink", 0)), int(payload.get("downlink", 0)),
                              int(payload.get("month_uplink", 0)), int(payload.get("month_downlink", 0)), int(payload.get("sequence", 0)))
        elif event["type"] == "profile.upsert":
            name, token = safe_label(str(payload.get("name", ""))), str(payload.get("token", ""))
            if name and token:
                self.ensure_profile(name, str(payload.get("selector", "all")),
                                    str(payload.get("profile_key", "legacy")), token)

    def federation_manifest(self) -> dict[str, Any]:
        heads = self.db.connection.execute("SELECT author_id,author_seq,event_hash,lamport FROM federation_heads ORDER BY author_id").fetchall()
        return {"api_version": API_VERSION, "node_id": self.load_config().get("node_id", ""),
                "heads": [dict(row) for row in heads], "generated_at": utc_now()}

    def federation_events_since(self, manifest: dict[str, Any] | None = None) -> list[dict[str, Any]]:
        seen = {str(item.get("author_id")): int(item.get("author_seq", 0)) for item in (manifest or {}).get("heads", []) if isinstance(item, dict)}
        rows = self.db.connection.execute("SELECT * FROM federation_events ORDER BY author_id,author_seq").fetchall()
        return [{key: row[key] for key in ("event_id", "author_id", "author_seq", "prev_hash", "lamport", "type", "entity_key", "payload", "created_at", "signature")} for row in rows if int(row["author_seq"]) > seen.get(str(row["author_id"]), 0)]

    def federation_import_events(self, events: Iterable[dict[str, Any]], trusted: dict[str, dict[str, str]] | None = None) -> int:
        event_list = list(events)
        for node_id, certificates in (trusted or {}).items():
            existing = self.db.connection.execute("SELECT root_certificate,identity_certificate FROM federation_keys WHERE node_id=?", (node_id,)).fetchone()
            if not existing or self._certificate_fingerprint_pem(str(existing["root_certificate"])) != self._certificate_fingerprint_pem(str(certificates.get("root_certificate", ""))):
                raise ClusterError("不得通过 events 接口无条件注入信任根")
        ordered, _ = self._validate_event_batch(event_list)
        count = 0
        for event in ordered:
            count += int(self.ingest_event(event))
        if any(str(event.get("type", "")) in FEDERATION_USER_EVENT_TYPES for event in event_list):
            try:
                self.apply_federation_users(refresh=False)
            except (ClusterError, OSError, sqlite3.Error):
                self.db.set_setting("federation.users.pending", "1")
                self.db.audit("federation.users.apply-pending", "events", "retry-required")
        return count

    def federation_trust_bundle(self) -> Path:
        bundle = self.pki / "federation-trust.pem"
        certificates = [str(row[0]).strip() for row in self.db.connection.execute("SELECT root_certificate FROM federation_keys WHERE revoked_at=0 ORDER BY node_id")]
        atomic_write(bundle, "\n".join(certificates) + "\n", 0o644)
        return bundle

    def federation_snapshot(self, profile: str = "legacy") -> dict[str, Any]:
        snapshot = self.local_snapshot(profile)
        digest = hashlib.sha256(json_dumps(snapshot.get("files", {})).encode("utf-8")).hexdigest()
        signed = {"node_id": self.load_config().get("node_id", ""), "profile_key": profile, "content_sha256": digest, "created_at": utc_now()}
        signed["signature"] = self._sign_federation(json_dumps(signed).encode("utf-8"))
        snapshot["federation_signature"] = signed
        return snapshot

    def record_federation_snapshot(self, snapshot: dict[str, Any]) -> None:
        signature = snapshot.get("federation_signature") if isinstance(snapshot.get("federation_signature"), dict) else {}
        status = snapshot.get("status") if isinstance(snapshot.get("status"), dict) else {}
        node_id = str(status.get("node_id", ""))
        signed = {key: signature.get(key) for key in ("node_id", "profile_key", "content_sha256", "created_at")}
        digest = hashlib.sha256(json_dumps(snapshot.get("files", {})).encode("utf-8")).hexdigest()
        if node_id != signed.get("node_id") or digest != signed.get("content_sha256") or not self._verify_federation_signature(self._event_certificate(node_id), json_dumps(signed).encode("utf-8"), str(signature.get("signature", ""))):
            raise ClusterError("订阅快照签名或哈希无效")
        try:
            created_at = int(signed.get("created_at", 0))
        except (TypeError, ValueError) as exc:
            raise ClusterError("订阅快照签名时间无效") from exc
        profile_key = safe_slug(str(signed.get("profile_key", "legacy")))
        clock_key = f"federation.snapshot.time.{node_id}.{profile_key}"
        latest = int(self.db.setting(clock_key, "0") or 0)
        if latest and created_at < latest:
            raise ClusterError("已拒绝回放旧版订阅快照")
        self.record_snapshot(snapshot, role="federation")
        self.db.set_setting(clock_key, str(created_at))
        self.create_event("snapshot.head", f"snapshot:{node_id}:{signed['profile_key']}", {"node_id": node_id, **signed})

    def record_transport_failure(self, candidate_id: str, reporter_id: str | None = None, when: int | None = None) -> dict[str, Any]:
        reporter_id = reporter_id or str(self.load_config().get("node_id", ""))
        when = int(when or utc_now())
        with self.db.connection:
            self.db.connection.execute("INSERT OR IGNORE INTO federation_failures(candidate_id,reporter_id,failed_at) VALUES(?,?,?)", (candidate_id, reporter_id, when))
            self.db.connection.execute("DELETE FROM federation_failures WHERE failed_at<?", (when - 60,))
            self.db.connection.execute("UPDATE nodes SET state='suspect',last_failure=?,updated_at=? WHERE id=?", (when, when, candidate_id))
        rows = self.db.connection.execute(
            "SELECT failed_at FROM federation_failures WHERE candidate_id=? AND reporter_id=? AND failed_at>=? "
            "ORDER BY failed_at",
            (candidate_id, reporter_id, when - 60),
        ).fetchall()
        failure_times = [int(row[0]) for row in rows]
        # Retries inside one request are transport resilience, not independent
        # evidence that a member died.  Automatic majority probing starts only
        # after three separate failed operations spanning at least 30 seconds.
        needs_probe = len(failure_times) >= 3 and failure_times[-1] - failure_times[-3] >= 30
        return {"candidate_id": candidate_id, "state": "suspect", "failures": len(failure_times),
                "failure_times": failure_times, "needs_probe": needs_probe}

    def record_transport_success(self, candidate_id: str, when: int | None = None) -> dict[str, Any]:
        when = int(when or utc_now())
        with self.db.connection:
            self.db.connection.execute("DELETE FROM federation_failures WHERE candidate_id=?", (candidate_id,))
            self.db.connection.execute("DELETE FROM federation_probe_observations WHERE candidate_id=?", (candidate_id,))
            self.db.connection.execute(
                "UPDATE nodes SET state='online',last_success=?,updated_at=? WHERE id=? AND state NOT IN ('revoked','removed')",
                (when, when, candidate_id),
            )
        return {"candidate_id": candidate_id, "state": "online", "cleared": True}

    def _active_federation_count(self) -> int:
        return int(self.db.connection.execute(
            "SELECT COUNT(*) FROM nodes n JOIN federation_keys k ON k.node_id=n.id "
            "WHERE n.state NOT IN ('legacy-unverified','revoked','removed') AND k.revoked_at=0"
        ).fetchone()[0])

    def probe_vote_for_member(self, candidate_id: str, nonce: str, requester_id: str = "") -> dict[str, Any]:
        if not re.fullmatch(r"[0-9a-f]{16,64}", nonce):
            raise ClusterError("probe nonce is invalid")
        local_id = str(self.load_config().get("node_id", ""))
        if candidate_id in {local_id, requester_id}:
            raise ClusterError("probe candidate is invalid")
        node = self.node(candidate_id)
        key = self.db.connection.execute(
            "SELECT revoked_at FROM federation_keys WHERE node_id=?", (candidate_id,)
        ).fetchone()
        if not key or int(key["revoked_at"]) or str(node["state"]) in {"legacy-unverified", "revoked", "removed"}:
            raise ClusterError("probe candidate is not an active trusted member")
        reachable = False
        try:
            response = mutual_request(self, str(node["endpoint_host"]), int(node["endpoint_port"]),
                                      "GET", "/v1/status", timeout=10)
            reachable = str(response.get("status", {}).get("node_id", "")) == candidate_id
        except (ClusterError, OSError, ssl.SSLError):
            reachable = False
        if reachable:
            self.record_transport_success(candidate_id)
        return self.create_probe_vote(candidate_id, reachable, nonce=nonce)

    def _coordinate_after_failures(self, candidate_id: str, failure_times: list[int]) -> dict[str, Any]:
        if len(failure_times) < 3 or max(failure_times) - min(failure_times) > 60:
            return {"candidate_id": candidate_id, "state": "suspect", "revoked": False,
                    "reason": "three failures within 60 seconds are required"}
        local_id = str(self.load_config().get("node_id", ""))
        for observed_at in failure_times[-3:]:
            vote = self.create_probe_vote(candidate_id, False, observed_at=observed_at,
                                          nonce=secrets.token_hex(16))
            with contextlib.suppress(ClusterError):
                self.record_probe_vote(vote)
        if self._active_federation_count() > 2:
            for voter in self.trusted_federation_nodes():
                voter_id = str(voter["id"])
                if voter_id in {candidate_id, local_id}:
                    continue
                nonce = secrets.token_hex(16)
                try:
                    response = mutual_request(
                        self, str(voter["endpoint_host"]), int(voter["endpoint_port"]), "POST",
                        "/v1/federation/probe", {"candidate_id": candidate_id, "nonce": nonce}, timeout=20,
                    )
                    vote = response.get("vote") if isinstance(response.get("vote"), dict) else {}
                    if vote.get("nonce") != nonce:
                        raise ClusterError("probe vote is not bound to the request nonce")
                    verdict = self.record_probe_vote(vote)
                    if bool(vote.get("reachable")):
                        return {**verdict, "revoked": False, "recovered": True}
                except (ClusterError, OSError, ssl.SSLError):
                    continue
        return self.finalize_suspect(candidate_id)

    def coordinate_member_health(self, candidate_id: str, *, probe: Any | None = None,
                                 now: int | None = None) -> dict[str, Any]:
        node = self.node(candidate_id)
        key = self.db.connection.execute(
            "SELECT revoked_at FROM federation_keys WHERE node_id=?", (candidate_id,)
        ).fetchone()
        if not key or int(key["revoked_at"]) or str(node["state"]) in {"legacy-unverified", "revoked", "removed"}:
            raise ClusterError("health candidate is not an active trusted member")
        base = int(now or utc_now())
        failures: list[int] = []
        for attempt in range(3):
            observed_at = base + attempt
            try:
                if probe is None:
                    response = mutual_request(self, str(node["endpoint_host"]), int(node["endpoint_port"]),
                                              "GET", "/v1/status", timeout=10)
                    if str(response.get("status", {}).get("node_id", "")) != candidate_id:
                        raise FederationTransportError("probe identity mismatch")
                else:
                    if not bool(probe(candidate_id, attempt)):
                        raise FederationTransportError("probe failed")
                return {**self.record_transport_success(candidate_id, observed_at), "revoked": False,
                        "attempts": attempt + 1}
            except (FederationTransportError, OSError, ssl.SSLError):
                failures.append(observed_at)
                self.record_transport_failure(candidate_id, when=observed_at)
        return {**self._coordinate_after_failures(candidate_id, failures), "attempts": 3}

    @staticmethod
    def canonical_probe_vote(vote: dict[str, Any]) -> bytes:
        return json_dumps({key: vote[key] for key in (
            "candidate_id", "voter_id", "reachable", "observed_at", "nonce"
        )}).encode("utf-8")

    def create_probe_vote(self, candidate_id: str, reachable: bool, *, observed_at: int | None = None,
                          nonce: str | None = None) -> dict[str, Any]:
        vote = {"candidate_id": candidate_id, "voter_id": str(self.load_config().get("node_id", "")),
                "reachable": bool(reachable), "observed_at": int(observed_at or utc_now()),
                "nonce": nonce or secrets.token_hex(16)}
        vote["signature"] = self._sign_federation(self.canonical_probe_vote(vote))
        vote["vote_id"] = hashlib.sha256(self.canonical_probe_vote(vote) + b"." + vote["signature"].encode("ascii")).hexdigest()
        return vote

    def verify_probe_vote(self, vote: dict[str, Any], *, now: int | None = None) -> dict[str, Any]:
        now = int(now or utc_now())
        required = {"candidate_id", "voter_id", "reachable", "observed_at", "nonce", "signature", "vote_id"}
        if set(vote) < required or not re.fullmatch(r"[0-9a-f]{32}", str(vote["candidate_id"])) \
                or not re.fullmatch(r"[0-9a-f]{32}", str(vote["voter_id"])):
            raise ClusterError("探测投票字段无效")
        if vote["candidate_id"] == vote["voter_id"] or not re.fullmatch(r"[0-9a-f]{16,64}", str(vote["nonce"])):
            raise ClusterError("候选节点不能为自己投票或 nonce 无效")
        observed_at = int(vote["observed_at"])
        if observed_at < now - 60 or observed_at > now + 5:
            raise ClusterError("探测投票已过期或时间超前")
        row = self.db.connection.execute(
            "SELECT n.state,k.root_certificate,k.revoked_at FROM nodes n JOIN federation_keys k ON k.node_id=n.id WHERE n.id=?",
            (vote["voter_id"],),
        ).fetchone()
        if not row or row["state"] in {"revoked", "removed"} or int(row["revoked_at"]):
            raise ClusterError("探测投票者不是活动成员")
        expected_id = hashlib.sha256(self.canonical_probe_vote(vote) + b"." + str(vote["signature"]).encode("ascii")).hexdigest()
        if expected_id != vote["vote_id"] or not self._verify_federation_signature(
            str(row["root_certificate"]), self.canonical_probe_vote(vote), str(vote["signature"])
        ):
            raise ClusterError("探测投票签名无效")
        return vote

    def _probe_verdict(self, candidate_id: str, now: int | None = None) -> dict[str, Any]:
        now = int(now or utc_now())
        active = self._active_federation_count()
        rows = self.db.connection.execute(
            "SELECT * FROM federation_probe_observations WHERE candidate_id=? AND reachable=0 AND observed_at>=? ORDER BY observed_at,vote_id",
            (candidate_id, now - 60),
        ).fetchall()
        valid_rows: list[sqlite3.Row] = []
        for row in rows:
            vote = {key: row[key] for key in (
                "vote_id", "candidate_id", "voter_id", "reachable", "observed_at", "nonce", "signature"
            )}
            vote["reachable"] = bool(vote["reachable"])
            try:
                self.verify_probe_vote(vote, now=now)
            except ClusterError:
                continue
            valid_rows.append(row)
        if active == 2:
            voters = {str(row["voter_id"]) for row in valid_rows}
            valid_count = len(valid_rows) if len(voters) == 1 else 0
            required = 3
        else:
            valid_count = len({str(row["voter_id"]) for row in valid_rows})
            required = max(1, ((max(0, active - 1)) // 2) + 1)
        return {"candidate_id": candidate_id, "unreachable_votes": valid_count, "required": required,
                "revocable": valid_count >= required, "vote_ids": [str(row["vote_id"]) for row in valid_rows]}

    def record_probe_vote(self, vote: dict[str, Any] | str, voter_id: str | None = None,
                          reachable: bool | None = None, signature: str = "") -> dict[str, Any]:
        if not isinstance(vote, dict):
            candidate_id = vote
            if voter_id != self.load_config().get("node_id") or signature:
                raise ClusterError("远端探测投票必须提交完整规范化载荷")
            vote = self.create_probe_vote(candidate_id, bool(reachable))
        self.verify_probe_vote(vote)
        if bool(vote["reachable"]):
            return {**self.record_transport_success(str(vote["candidate_id"])),
                    "unreachable_votes": 0, "required": self._probe_verdict(str(vote["candidate_id"]))["required"],
                    "revocable": False, "vote_ids": []}
        try:
            with self.db.connection:
                self.db.connection.execute(
                    "INSERT INTO federation_probe_observations(vote_id,candidate_id,voter_id,reachable,observed_at,nonce,signature,received_at) VALUES(?,?,?,?,?,?,?,?)",
                    (vote["vote_id"], vote["candidate_id"], vote["voter_id"], int(bool(vote["reachable"])),
                     int(vote["observed_at"]), vote["nonce"], vote["signature"], utc_now()),
                )
        except sqlite3.IntegrityError as exc:
            raise ClusterError("探测投票 nonce 或 vote_id 已重放") from exc
        return self._probe_verdict(str(vote["candidate_id"]))

    def finalize_suspect(self, candidate_id: str) -> dict[str, Any]:
        verdict = self._probe_verdict(candidate_id)
        if not verdict["revocable"]:
            return {**verdict, "revoked": False}
        head = self.db.connection.execute("SELECT author_seq FROM federation_heads WHERE author_id=?", (candidate_id,)).fetchone()
        event = self.create_event("revocation.proof", f"member:{candidate_id}", {
            "node_id": candidate_id, "reason": "majority probe failure", "votes": verdict["unreachable_votes"],
            "required": verdict["required"], "vote_ids": verdict["vote_ids"],
            "revoked_after_seq": int(head[0] if head else 0),
        })
        return {**verdict, "revoked": True, "proof": event}

    def revoke_member(self, node_id: str, reason: str = "manual") -> dict[str, Any]:
        if not self.is_federation():
            raise ClusterError("当前不是联邦模式")
        head = self.db.connection.execute("SELECT author_seq FROM federation_heads WHERE author_id=?", (node_id,)).fetchone()
        event = self.create_event("member.revoke", f"member:{node_id}", {
            "node_id": node_id, "reason": safe_label(reason, 200),
            "revoked_after_seq": int(head[0] if head else 0),
        })
        return {"event": event, "node_id": node_id}

    def federation_cleanup_plan(self, node_id: str | None = None) -> dict[str, Any]:
        node_id = node_id or str(self.load_config().get("node_id", ""))
        row = self.db.connection.execute("SELECT revoked_at FROM federation_keys WHERE node_id=?", (node_id,)).fetchone()
        tombstone = self.db.connection.execute(
            "SELECT deleted FROM federation_entities WHERE entity_key=?", ("member:" + node_id,)
        ).fetchone()
        return {"revoked": bool((row and row[0]) or (tombstone and tombstone[0])), "node_id": node_id,
                "remove": ["federation memberships", "federation users", "federation subscription profiles"],
                "preserve": ["proxy protocols", "local Lun data", "visit monitor"]}

    def membership_status_proof(self, node_id: str, nonce: str) -> dict[str, Any]:
        if not re.fullmatch(r"[0-9A-Za-z_-]{16,128}", nonce):
            raise ClusterError("membership-status nonce 无效")
        signer = str(self.load_config().get("node_id", ""))
        certificate = self.federation_root_certificate()
        proof = {"node_id": node_id, "revoked": self.federation_cleanup_plan(node_id)["revoked"],
                 "nonce": nonce, "created_at": utc_now(), "signer": signer,
                 "certificate_fingerprint": self._certificate_fingerprint_pem(certificate)}
        proof["signature"] = self._sign_federation(json_dumps(proof).encode("utf-8"))
        proof["signer_root_certificate"] = certificate
        return proof

    def verify_membership_status_proof(self, proof: dict[str, Any], expected_node_id: str,
                                       expected_nonce: str, *, now: int | None = None,
                                       consume: bool = False) -> bool:
        now = int(now or utc_now())
        signed = {key: proof.get(key) for key in (
            "node_id", "revoked", "nonce", "created_at", "signer", "certificate_fingerprint"
        )}
        if signed["node_id"] != expected_node_id or signed["nonce"] != expected_nonce:
            raise ClusterError("membership-status proof 请求绑定不匹配")
        if int(signed["created_at"] or 0) < now - 60 or int(signed["created_at"] or 0) > now + 5:
            raise ClusterError("membership-status proof 已过期")
        signer = str(signed["signer"])
        row = self.db.connection.execute("SELECT root_certificate,root_fingerprint,revoked_at FROM federation_keys WHERE node_id=?", (signer,)).fetchone()
        certificate = str(proof.get("signer_root_certificate", ""))
        fingerprint = self._certificate_fingerprint_pem(certificate)
        if not row or int(row["revoked_at"]) or fingerprint != signed["certificate_fingerprint"] or fingerprint != str(row["root_fingerprint"]):
            raise ClusterError("membership-status proof 签名者不受信任")
        if not self._verify_federation_signature(certificate, json_dumps(signed).encode("utf-8"), str(proof.get("signature", ""))):
            raise ClusterError("membership-status proof 签名无效")
        proof_id = hashlib.sha256(
            json_dumps(signed).encode("utf-8") + b"." + str(proof.get("signature", "")).encode("ascii")
        ).hexdigest()
        if consume:
            key = "membership.proof." + proof_id
            if self.db.setting(key):
                raise ClusterError("membership-status proof has already been consumed")
            self.db.set_setting(key, now)
        return True

    def _after_revoked_cleanup_reset(self) -> None:
        """Test seam after destructive reset and before commit."""

    def exit_revoked_federation(self, proof: dict[str, Any], expected_nonce: str) -> dict[str, Any]:
        config = self.load_config()
        local_id = str(config.get("node_id", ""))
        if not self.is_federation() or not re.fullmatch(r"[0-9a-f]{32}", local_id):
            raise ClusterError("local node is not an active federation identity")
        self.verify_membership_status_proof(proof, local_id, expected_nonce)
        if not bool(proof.get("revoked")) or str(proof.get("signer", "")) == local_id:
            raise ClusterError("proof does not establish revocation by a surviving trusted member")
        old_cluster = str(config.get("cluster_id", ""))
        profile_tokens = [str(row[0]) for row in self.db.connection.execute("SELECT token FROM profiles")]
        multi_db = self.root / "modules" / "multiuser" / "data" / "lun.db"
        multi_generated = self.root / "modules" / "multiuser" / "generated"
        webroot = self.root.parent / "weblun"
        preserved_files = [self.root / "xr.json", self.root / "sb.json"]
        with tempfile.TemporaryDirectory(dir=self.module) as temporary:
            checkpoint_dir = Path(temporary)
            cluster_db = checkpoint_dir / "cluster.db"
            destination = sqlite3.connect(cluster_db)
            try:
                self.db.connection.backup(destination)
            finally:
                destination.close()
            config_bytes = self.config_path.read_bytes() if self.config_path.is_file() else None
            for source, name in ((self.pki, "pki"), (self.cache, "cache"),
                                 (multi_generated, "multi-generated")):
                if source.exists():
                    shutil.copytree(source, checkpoint_dir / name)
            for token in profile_tokens:
                source = webroot / token
                if source.exists():
                    shutil.copytree(source, checkpoint_dir / "web" / token)
            multi_checkpoint = checkpoint_dir / "multiuser.db"
            if multi_db.is_file():
                source_db = sqlite3.connect(f"file:{multi_db.resolve().as_posix()}?mode=ro", uri=True)
                target_db = sqlite3.connect(multi_checkpoint)
                try:
                    source_db.backup(target_db)
                finally:
                    source_db.close()
                    target_db.close()
            file_backups = {path: path.read_bytes() for path in preserved_files if path.is_file()}
            history = [tuple(row) for row in self.db.connection.execute(
                "SELECT node_id,server_number,allocated_at FROM node_number_history ORDER BY server_number"
            )]
            try:
                if multi_db.exists():
                    self._apply_federation_user_bundle({"schema_version": 1, "users": []})
                fresh_path = checkpoint_dir / "fresh.db"
                fresh = Database(fresh_path)
                try:
                    fresh.migrate()
                    with fresh.connection:
                        fresh.connection.executemany(
                            "INSERT OR IGNORE INTO node_number_history(node_id,server_number,allocated_at) VALUES(?,?,?)",
                            history,
                        )
                finally:
                    fresh.close()
                self.replace_database(fresh_path)
                shutil.rmtree(self.pki, ignore_errors=True)
                shutil.rmtree(self.cache, ignore_errors=True)
                for token in profile_tokens:
                    shutil.rmtree(webroot / token, ignore_errors=True)
                retired_numbers = sorted({int(row[1]) for row in history if int(row[1]) > 0})
                self.save_config({
                    "enabled": False, "role": "disabled", "retired_node_id": local_id,
                    "retired_cluster_id": old_cluster, "retired_server_numbers": retired_numbers,
                    "revoked_at": utc_now(),
                })
                self._after_revoked_cleanup_reset()
            except Exception:
                self.replace_database(cluster_db)
                if config_bytes is None:
                    self.config_path.unlink(missing_ok=True)
                else:
                    atomic_write(self.config_path, config_bytes, 0o600)
                for target, name in ((self.pki, "pki"), (self.cache, "cache"),
                                     (multi_generated, "multi-generated")):
                    shutil.rmtree(target, ignore_errors=True)
                    backup = checkpoint_dir / name
                    if backup.exists():
                        shutil.copytree(backup, target)
                for token in profile_tokens:
                    shutil.rmtree(webroot / token, ignore_errors=True)
                    backup = checkpoint_dir / "web" / token
                    if backup.exists():
                        shutil.copytree(backup, webroot / token)
                if multi_checkpoint.is_file():
                    multi_db.parent.mkdir(parents=True, exist_ok=True)
                    source_db = sqlite3.connect(
                        f"file:{multi_checkpoint.resolve().as_posix()}?mode=ro", uri=True
                    )
                    target_db = sqlite3.connect(multi_db)
                    try:
                        source_db.backup(target_db)
                    finally:
                        source_db.close()
                        target_db.close()
                for path in preserved_files:
                    if path in file_backups:
                        atomic_write(path, file_backups[path], 0o600)
                    else:
                        path.unlink(missing_ok=True)
                self.secure_files()
                raise
        self.secure_files()
        return {"cleaned": True, "retired_node_id": local_id, "retired_cluster_id": old_cluster,
                "preserved": ["proxy protocols", "ordinary local users", "visit monitor"],
                "next": "run federation-init to create a new identity"}

    def check_self_revocation(self, *, query: Any | None = None) -> dict[str, Any]:
        if not self.is_federation():
            return {"checked": 0, "cleaned": False, "skipped": True}
        local_id = str(self.load_config().get("node_id", ""))
        checked = 0
        failures: dict[str, str] = {}
        peers = [dict(row) for row in self.trusted_federation_nodes()]
        responses: dict[str, tuple[str, Any]] = {}

        def fetch(peer: dict[str, Any]) -> tuple[str, Any]:
            nonce = secrets.token_urlsafe(24)
            try:
                if query is None:
                    response = membership_status_request(self, peer, local_id, nonce, timeout=4)
                else:
                    response = query(peer, nonce)
                return nonce, response
            except (ClusterError, OSError, ssl.SSLError) as exc:
                return nonce, exc

        if peers:
            with concurrent.futures.ThreadPoolExecutor(max_workers=min(8, len(peers))) as executor:
                futures = {executor.submit(fetch, peer): str(peer["id"]) for peer in peers}
                for future in concurrent.futures.as_completed(futures):
                    responses[futures[future]] = future.result()

        for peer in peers:
            peer_id = str(peer["id"])
            nonce, response = responses.get(
                peer_id, ("", ClusterError("membership-status unavailable"))
            )
            if isinstance(response, Exception):
                failures[peer_id] = response.__class__.__name__
                continue
            verified_revoked = False
            try:
                proof = response.get("proof") if isinstance(response, dict) \
                    and isinstance(response.get("proof"), dict) else response
                if not isinstance(proof, dict):
                    raise ClusterError("membership-status response has no proof")
                if str(proof.get("signer", "")) != peer_id:
                    raise ClusterError("membership-status signer does not match the queried peer")
                self.verify_membership_status_proof(proof, local_id, nonce)
                checked += 1
                if bool(proof.get("revoked")):
                    verified_revoked = True
                    return {**self.exit_revoked_federation(proof, nonce), "checked": checked,
                            "signer": peer_id}
                self.verify_membership_status_proof(proof, local_id, nonce, consume=True)
            except (ClusterError, OSError, ssl.SSLError) as exc:
                if verified_revoked:
                    raise
                failures[peer_id] = exc.__class__.__name__
        return {"checked": checked, "cleaned": False, "failures": failures}

    def federation_public_bundle(self) -> dict[str, Any]:
        config = self.load_config()
        trust = [dict(row) for row in self.db.connection.execute(
            "SELECT node_id,root_certificate,identity_certificate,root_fingerprint,identity_fingerprint,"
            "revoked_at,revoked_after_seq,revocation_event_id FROM federation_keys ORDER BY node_id"
        ).fetchall()]
        roster = [dict(row) for row in self.db.connection.execute(
            "SELECT id,endpoint_host,endpoint_hosts,endpoint_port,internal_port,remark,server_number,country_code,country,region,city,provider,state FROM nodes ORDER BY server_number,id"
        ).fetchall()]
        bundle = {"format": 3, "api_version": API_VERSION, "cluster_id": config.get("cluster_id", ""),
                  "node_id": config.get("node_id", ""), "status": self.local_status(),
                  "root_certificate": self.federation_root_certificate(),
                  "identity_certificate": self.federation_identity_certificate(),
                  "manifest": self.federation_manifest(), "events": self.federation_events_since({}),
                  "trust": trust, "roster": roster, "created_at": utc_now(), "nonce": secrets.token_hex(16)}
        bundle["signature"] = self._sign_federation(json_dumps(bundle).encode("utf-8"))
        return bundle

    def _validate_event_batch(self, events: Iterable[dict[str, Any]], anchor: dict[str, dict[str, Any]] | None = None) -> tuple[list[dict[str, Any]], dict[str, dict[str, Any]]]:
        known: dict[str, dict[str, Any]] = {}
        for row in self.db.connection.execute("SELECT * FROM federation_keys"):
            known[str(row["node_id"])] = dict(row)
        for node_id, value in (anchor or {}).items():
            root = str(value.get("root_certificate", ""))
            identity = str(value.get("identity_certificate", ""))
            root_fp, identity_fp = self.validate_federation_certificates(node_id, root, identity)
            existing = known.get(node_id)
            if existing and str(existing.get("root_fingerprint") or self._certificate_fingerprint_pem(str(existing["root_certificate"]))) != root_fp:
                raise ClusterError("bundle 尝试替换活动 node_id 的根证书")
            known[node_id] = {**(existing or {}), "node_id": node_id, "root_certificate": root,
                              "identity_certificate": identity, "root_fingerprint": root_fp,
                              "identity_fingerprint": identity_fp, "revoked_at": int((existing or {}).get("revoked_at", 0)),
                              "revoked_after_seq": int((existing or {}).get("revoked_after_seq", -1))}
        heads = {str(row["author_id"]): (int(row["author_seq"]), str(row["event_hash"]))
                 for row in self.db.connection.execute("SELECT * FROM federation_heads")}
        pending = []
        for event in events:
            if not isinstance(event, dict):
                raise ClusterError("bundle 事件不是对象")
            existing = self.db.connection.execute("SELECT event_hash FROM federation_events WHERE event_id=?", (event.get("event_id", ""),)).fetchone()
            if existing:
                continue
            pending.append(dict(event))
        accepted: list[dict[str, Any]] = []
        while pending:
            progress = False
            for event in sorted(list(pending), key=lambda item: (str(item.get("author_id", "")), int(item.get("author_seq", 0)))):
                required = {"event_id", "author_id", "author_seq", "prev_hash", "lamport", "type", "entity_key", "payload", "created_at", "signature"}
                if set(event) < required or event.get("type") not in FEDERATION_EVENT_TYPES or event_hash(event) != event.get("event_id"):
                    raise ClusterError("bundle 事件字段或哈希无效")
                author = str(event["author_id"])
                key = known.get(author)
                if not key:
                    continue
                expected_seq, expected_hash = heads.get(author, (0, ""))
                if int(event["author_seq"]) != expected_seq + 1 or str(event["prev_hash"]) != expected_hash:
                    continue
                cutoff = int(key.get("revoked_after_seq", -1))
                if int(key.get("revoked_at", 0)) and (cutoff < 0 or int(event["author_seq"]) > cutoff):
                    raise ClusterError("bundle 包含撤销边界后的作者事件")
                if not self._verify_federation_signature(str(key["root_certificate"]), canonical_event_fields(event), str(event["signature"])):
                    raise ClusterError("bundle 事件签名无效")
                try:
                    payload = json.loads(str(event["payload"]))
                except json.JSONDecodeError as exc:
                    raise ClusterError("bundle 事件载荷无效") from exc
                if not isinstance(payload, dict):
                    raise ClusterError("bundle 事件载荷必须是对象")
                self._validate_event_payload(str(event["type"]), str(event["entity_key"]), payload)
                if event["type"] == "node.metadata" and isinstance(payload.get("status"), dict):
                    node_id = str(payload.get("node_id", ""))
                    if event["entity_key"] != f"node:{node_id}" or author != node_id:
                        raise ClusterError("节点元数据必须由节点自身签名")
                if event["type"] == "member.upsert":
                    status = payload.get("status") if isinstance(payload.get("status"), dict) else {}
                    member_id = str(status.get("node_id", ""))
                    root, identity = str(payload.get("root_certificate", "")), str(payload.get("identity_certificate", ""))
                    root_fp, identity_fp = self.validate_federation_certificates(member_id, root, identity)
                    old = known.get(member_id)
                    if old and str(old.get("root_fingerprint") or self._certificate_fingerprint_pem(str(old["root_certificate"]))) != root_fp:
                        raise ClusterError("成员事件尝试替换活动 node_id 的根证书")
                    known.setdefault(member_id, {"node_id": member_id, "root_certificate": root,
                                                 "identity_certificate": identity, "root_fingerprint": root_fp,
                                                 "identity_fingerprint": identity_fp, "revoked_at": 0,
                                                 "revoked_after_seq": -1})
                elif event["type"] in {"member.revoke", "revocation.proof"}:
                    target = str(payload.get("node_id", ""))
                    if target in known:
                        known[target]["revoked_at"] = int(event["created_at"])
                        known[target]["revoked_after_seq"] = int(payload.get("revoked_after_seq", 0))
                heads[author] = (int(event["author_seq"]), str(event["event_id"]))
                accepted.append(event)
                pending.remove(event)
                progress = True
            if not progress:
                raise ClusterError("bundle 事件依赖不完整、作者不受信或事件链存在缺口")
        return accepted, known

    def validate_federation_bundle(self, bundle: dict[str, Any], *, pinned_identity_fingerprint: str = "",
                                   allow_cluster_adopt: bool = False, allow_foreign_single: bool = False) -> dict[str, Any]:
        unsigned = {key: value for key, value in bundle.items() if key != "signature"}
        node_id = str(bundle.get("node_id", ""))
        cluster_id = str(bundle.get("cluster_id", ""))
        if int(bundle.get("format", 0)) != 3 or not re.fullmatch(r"[0-9a-f]{32}", cluster_id):
            raise ClusterError("联邦 bundle 格式或 cluster_id 无效")
        root, identity = str(bundle.get("root_certificate", "")), str(bundle.get("identity_certificate", ""))
        root_fp, identity_fp = self.validate_federation_certificates(node_id, root, identity)
        if pinned_identity_fingerprint and not hmac.compare_digest(identity_fp, pinned_identity_fingerprint):
            raise ClusterError("联邦 bundle 身份证书与加入地址指纹不一致")
        if not self._verify_federation_signature(root, json_dumps(unsigned).encode("utf-8"), str(bundle.get("signature", ""))):
            raise ClusterError("联邦 bundle 签名无效")
        local = self.load_config()
        local_cluster = str(local.get("cluster_id", ""))
        local_members = int(self.db.connection.execute("SELECT COUNT(*) FROM federation_keys").fetchone()[0])
        remote_members = len(bundle.get("trust", [])) if isinstance(bundle.get("trust"), list) else 0
        adopt = bool(local_cluster != cluster_id and allow_cluster_adopt and local_members <= 1)
        foreign_single = bool(local_cluster != cluster_id and allow_foreign_single and remote_members <= 1)
        if local_cluster and local_cluster != cluster_id and not adopt and not foreign_single:
            if local_members > 1 and remote_members > 1:
                raise ClusterError("拒绝合并两个 cluster_id 不同的既有多成员 federation")
            raise ClusterError("联邦 cluster_id 不一致")
        events = bundle.get("events") if isinstance(bundle.get("events"), list) else []
        ordered, known = self._validate_event_batch(events, {node_id: {
            "root_certificate": root, "identity_certificate": identity,
        }})
        for item in bundle.get("trust", []) if isinstance(bundle.get("trust"), list) else []:
            if not isinstance(item, dict) or str(item.get("node_id", "")) not in known:
                raise ClusterError("bundle trust 未由签名成员事件授权")
            trusted = known[str(item["node_id"])]
            if self._certificate_fingerprint_pem(str(item.get("root_certificate", ""))) != str(trusted["root_fingerprint"]):
                raise ClusterError("bundle trust 与签名成员事件不一致")
        return {"node_id": node_id, "cluster_id": cluster_id, "adopt_cluster": adopt,
                "root_certificate": root, "identity_certificate": identity, "root_fingerprint": root_fp,
                "identity_fingerprint": identity_fp, "events": ordered}

    def _restore_database_checkpoint(self, database: Path, config_bytes: bytes | None) -> None:
        self.replace_database(database)
        if config_bytes is None:
            self.config_path.unlink(missing_ok=True)
        else:
            atomic_write(self.config_path, config_bytes, 0o600)

    def import_federation_bundle(self, bundle: dict[str, Any], *, pinned_identity_fingerprint: str = "",
                                 allow_cluster_adopt: bool = False, allow_foreign_single: bool = False) -> dict[str, Any]:
        plan = self.validate_federation_bundle(bundle, pinned_identity_fingerprint=pinned_identity_fingerprint,
                                               allow_cluster_adopt=allow_cluster_adopt,
                                               allow_foreign_single=allow_foreign_single)
        with tempfile.TemporaryDirectory(dir=self.module) as temporary:
            checkpoint = Path(temporary) / "cluster.db"
            destination = sqlite3.connect(checkpoint)
            try:
                self.db.connection.backup(destination)
            finally:
                destination.close()
            config_bytes = self.config_path.read_bytes() if self.config_path.is_file() else None
            try:
                if plan["adopt_cluster"]:
                    config = self.load_config()
                    config["cluster_id"] = plan["cluster_id"]
                    self.save_config(config)
                self.register_federation_key(plan["node_id"], plan["root_certificate"], plan["identity_certificate"])
                accepted = self.federation_import_events(plan["events"])
                return {**plan, "accepted": accepted}
            except Exception:
                self._restore_database_checkpoint(checkpoint, config_bytes)
                raise

    @staticmethod
    def canonical_join_transaction(transaction: dict[str, Any]) -> bytes:
        return json_dumps({key: transaction[key] for key in (
            "transaction_id", "initiator_id", "responder_id", "bundle_sha256", "created_at"
        )}).encode("utf-8")

    def create_join_transaction(self, bundle: dict[str, Any], responder_id: str) -> dict[str, Any]:
        transaction = {
            "transaction_id": secrets.token_hex(16),
            "initiator_id": str(self.load_config().get("node_id", "")),
            "responder_id": responder_id,
            "bundle_sha256": hashlib.sha256(json_dumps(bundle).encode("utf-8")).hexdigest(),
            "created_at": utc_now(),
        }
        transaction["signature"] = self._sign_federation(self.canonical_join_transaction(transaction))
        return transaction

    def verify_join_transaction(self, transaction: dict[str, Any], bundle: dict[str, Any],
                                responder_id: str, *, now: int | None = None) -> dict[str, Any]:
        required = {"transaction_id", "initiator_id", "responder_id", "bundle_sha256", "created_at", "signature"}
        now = int(now or utc_now())
        if set(transaction) < required or not re.fullmatch(r"[0-9a-f]{32}", str(transaction.get("transaction_id", ""))):
            raise ClusterError("联邦配对 transaction_id 无效")
        if transaction.get("initiator_id") != bundle.get("node_id") or transaction.get("responder_id") != responder_id:
            raise ClusterError("联邦配对事务身份绑定不匹配")
        created_at = int(transaction.get("created_at", 0))
        if created_at < now - JOIN_TTL or created_at > now + 5:
            raise ClusterError("联邦配对事务已过期")
        digest = hashlib.sha256(json_dumps(bundle).encode("utf-8")).hexdigest()
        if not hmac.compare_digest(str(transaction.get("bundle_sha256", "")), digest):
            raise ClusterError("联邦配对事务未绑定当前 bundle")
        root = str(bundle.get("root_certificate", ""))
        if not self._verify_federation_signature(
            root, self.canonical_join_transaction(transaction), str(transaction.get("signature", ""))
        ):
            raise ClusterError("联邦配对事务签名无效")
        return transaction

    def federation_join_status(self, token: str, transaction: dict[str, Any]) -> dict[str, Any]:
        transaction_id = str(transaction.get("transaction_id", ""))
        row = self.db.connection.execute(
            "SELECT * FROM federation_join_transactions WHERE transaction_id=? AND direction='incoming'",
            (transaction_id,),
        ).fetchone()
        token_hash = hashlib.sha256(token.encode("utf-8")).hexdigest()
        if not row or not hmac.compare_digest(str(row["token_hash"]), token_hash) or row["status"] != "committed":
            raise ClusterError("联邦配对事务不存在或尚未提交")
        stored = json.loads(str(row["transaction_payload"]))
        if not hmac.compare_digest(json_dumps(stored), json_dumps(transaction)):
            raise ClusterError("联邦配对事务状态请求不匹配")
        key = self.db.connection.execute(
            "SELECT root_certificate,revoked_at FROM federation_keys WHERE node_id=?", (row["peer_id"],)
        ).fetchone()
        if not key or int(key["revoked_at"]) or not self._verify_federation_signature(
            str(key["root_certificate"]), self.canonical_join_transaction(stored), str(stored.get("signature", ""))
        ):
            raise ClusterError("联邦配对事务状态签名无效")
        return {"transaction_id": transaction_id, "bundle": json.loads(str(row["response_bundle"]))}

    def save_outgoing_join_transaction(self, token: str, transaction: dict[str, Any],
                                       response_bundle: dict[str, Any] | None, status: str) -> None:
        now = utc_now()
        with self.db.connection:
            self.db.connection.execute(
                "INSERT INTO federation_join_transactions(transaction_id,direction,token_hash,peer_id,bundle_sha256,"
                "transaction_signature,transaction_payload,response_bundle,status,created_at,updated_at) "
                "VALUES(?,?,?,?,?,?,?,?,?,?,?) ON CONFLICT(transaction_id) DO UPDATE SET "
                "response_bundle=excluded.response_bundle,status=excluded.status,updated_at=excluded.updated_at",
                (transaction["transaction_id"], "outgoing", hashlib.sha256(token.encode("utf-8")).hexdigest(),
                 transaction["responder_id"], transaction["bundle_sha256"], transaction["signature"],
                 json_dumps(transaction), json_dumps(response_bundle) if response_bundle else "", status, now, now),
            )

    def accept_federation_join(self, token: str, bundle: dict[str, Any],
                               transaction: dict[str, Any]) -> dict[str, Any]:
        digest = hashlib.sha256(token.encode()).hexdigest()
        self.verify_join_transaction(transaction, bundle, str(self.load_config().get("node_id", "")))
        transaction_id = str(transaction["transaction_id"])
        existing = self.db.connection.execute(
            "SELECT * FROM federation_join_transactions WHERE transaction_id=?", (transaction_id,)
        ).fetchone()
        if existing:
            if existing["direction"] != "incoming" or not hmac.compare_digest(str(existing["token_hash"]), digest) \
                    or not hmac.compare_digest(str(existing["transaction_payload"]), json_dumps(transaction)):
                raise ClusterError("联邦配对 transaction_id 已被其他请求使用")
            if existing["status"] != "committed":
                raise ClusterError("联邦配对事务尚未完成，可稍后重试")
            return {"node_id": existing["peer_id"], "transaction_id": transaction_id,
                    "bundle": json.loads(str(existing["response_bundle"])), "replayed": True}
        row = self.db.connection.execute("SELECT * FROM join_tokens WHERE token_hash=?", (digest,)).fetchone()
        if not row or row["used_at"] or row["expires_at"] < utc_now():
            raise ClusterError("一次性加入令牌无效、已使用或已过期")
        self.validate_federation_bundle(bundle, allow_cluster_adopt=True)
        with tempfile.TemporaryDirectory(dir=self.module) as temporary:
            checkpoint = Path(temporary) / "cluster.db"
            destination = sqlite3.connect(checkpoint)
            try:
                self.db.connection.backup(destination)
            finally:
                destination.close()
            config_bytes = self.config_path.read_bytes() if self.config_path.is_file() else None
            try:
                imported = self.import_federation_bundle(bundle, allow_cluster_adopt=True)
                status = bundle.get("status") if isinstance(bundle.get("status"), dict) else {}
                payload = self.federation_member_payload(
                    {**status, "node_id": imported["node_id"]}, imported["root_certificate"],
                    imported["identity_certificate"], False,
                )
                confirmation = self.create_event("member.upsert", f"member:{imported['node_id']}", payload)
                response_bundle = self.federation_public_bundle()
                now = utc_now()
                with self.db.connection:
                    self.db.connection.execute(
                        "INSERT INTO federation_join_transactions(transaction_id,direction,token_hash,peer_id,bundle_sha256,"
                        "transaction_signature,transaction_payload,response_bundle,status,created_at,updated_at) "
                        "VALUES(?,?,?,?,?,?,?,?,?,?,?)",
                        (transaction_id, "incoming", digest, imported["node_id"], transaction["bundle_sha256"],
                         transaction["signature"], json_dumps(transaction), json_dumps(response_bundle),
                         "committed", now, now),
                    )
                self.consume_join_token(token)
                return {"node_id": imported["node_id"], "confirmation": confirmation,
                        "transaction_id": transaction_id, "bundle": response_bundle}
            except Exception:
                self._restore_database_checkpoint(checkpoint, config_bytes)
                raise

    def federation_register_peer(self, bundle: dict[str, Any], remark: str = "") -> dict[str, Any]:
        status = bundle.get("status") if isinstance(bundle.get("status"), dict) else {}
        node_id = str(bundle.get("node_id", status.get("node_id", "")))
        if not re.fullmatch(r"[0-9a-f]{32}", node_id) or node_id == self.load_config().get("node_id"):
            raise ClusterError("联邦成员身份无效")
        plan = self.import_federation_bundle(bundle, allow_foreign_single=True)
        confirmation = self.confirm_federation_member(bundle, remark)
        return {"node_id": node_id, "event": confirmation.get("event"),
                "confirmed": confirmation["created"], "accepted": plan["accepted"]}

    def confirm_federation_member(self, bundle: dict[str, Any], remark: str = "") -> dict[str, Any]:
        """Sign local trust once so a newly paired member can propagate to existing peers."""
        status = bundle.get("status") if isinstance(bundle.get("status"), dict) else {}
        node_id = str(bundle.get("node_id", status.get("node_id", "")))
        local_id = str(self.load_config().get("node_id", ""))
        if not re.fullmatch(r"[0-9a-f]{32}", node_id) or node_id == local_id:
            raise ClusterError("联邦成员身份无效")
        key = self.db.connection.execute(
            "SELECT root_certificate,identity_certificate,revoked_at FROM federation_keys WHERE node_id=?",
            (node_id,),
        ).fetchone()
        if not key or int(key["revoked_at"]):
            raise ClusterError("联邦成员未受信或已撤销")
        root, identity = str(key["root_certificate"]), str(key["identity_certificate"])
        existing = self.db.connection.execute(
            "SELECT payload FROM federation_events WHERE author_id=? AND type='member.upsert' "
            "AND entity_key=? ORDER BY author_seq DESC LIMIT 1",
            (local_id, f"member:{node_id}"),
        ).fetchone()
        if existing:
            with contextlib.suppress(json.JSONDecodeError):
                previous = json.loads(str(existing["payload"]))
                if previous.get("root_certificate") == root \
                        and previous.get("identity_certificate") == identity:
                    return {"created": False, "event": None}
        confirmed_status = {**status, "node_id": node_id}
        if remark:
            confirmed_status["remark"] = safe_label(remark)
        payload = self.federation_member_payload(confirmed_status, root, identity)
        return {"created": True,
                "event": self.create_event("member.upsert", f"member:{node_id}", payload)}

    def _encrypt_backup_payload(self, plaintext: bytes, target: Path, password: str) -> Path:
        if len(password) < 8:
            raise ClusterError("备份口令至少8个字符")
        salt, iv = secrets.token_bytes(16), secrets.token_bytes(16)
        material = hashlib.pbkdf2_hmac("sha256", password.encode(), salt, BACKUP_KDF_ITERATIONS, 64)
        with tempfile.TemporaryDirectory(dir=self.module) as temporary:
            source, cipher = Path(temporary) / "plain", Path(temporary) / "cipher"
            source.write_bytes(plaintext)
            self._run([shutil.which("openssl") or "openssl", "enc", "-aes-256-cbc", "-K", material[:32].hex(), "-iv", iv.hex(), "-in", str(source), "-out", str(cipher)])
            encrypted = cipher.read_bytes()
        header = BACKUP_MAGIC + salt + iv
        atomic_write(target, header + encrypted + hmac.new(material[32:], header + encrypted, hashlib.sha256).digest(), 0o600)
        return target

    def export_federation_backup(self, target: Path, password: str, *, include_identity: bool = False) -> Path:
        """Portable federation data backup. Private material is opt-in only."""
        self.db.connection.execute("PRAGMA wal_checkpoint(FULL)")
        with tempfile.TemporaryDirectory(dir=self.module) as temporary:
            directory, db_copy = Path(temporary), Path(temporary) / "cluster.db"
            destination = sqlite3.connect(db_copy)
            try:
                self.db.connection.backup(destination)
            finally:
                destination.close()
            config = dict(self.load_config())
            manifest = {"format": 3, "kind": "identity" if include_identity else "federation-data",
                        "api_version": API_VERSION, "cluster_id": config.get("cluster_id", ""),
                        "node_id": config.get("node_id", ""), "created_at": utc_now()}
            archive = directory / "federation.tar.gz"
            config_path, manifest_path = directory / "config.json", directory / "manifest.json"
            atomic_write(config_path, json.dumps(config, ensure_ascii=False, indent=2) + "\n", 0o600)
            atomic_write(manifest_path, json.dumps(manifest, ensure_ascii=False, indent=2) + "\n", 0o600)
            with tarfile.open(archive, "w:gz") as tar:
                tar.add(db_copy, arcname="data/cluster.db")
                tar.add(manifest_path, arcname="manifest.json")
                if include_identity:
                    tar.add(config_path, arcname="config.json")
                    for name in ("federation-root.crt", "federation-node.crt",
                                 "federation-root.key", "federation-node.key"):
                        path = self.pki / name
                        if not path.is_file():
                            raise ClusterError("完整身份备份缺少本机联邦身份文件")
                        tar.add(path, arcname=f"pki/{name}", recursive=False)
            return self._encrypt_backup_payload(archive.read_bytes(), target, password)

    def export_identity_backup(self, target: Path, password: str) -> Path:
        return self.export_federation_backup(target, password, include_identity=True)

    def _private_key_matches_certificate(self, private_key: bytes, certificate: bytes) -> bool:
        with tempfile.TemporaryDirectory(dir=self.module) as temporary:
            key_path, cert_path = Path(temporary) / "identity.key", Path(temporary) / "identity.crt"
            key_pub, cert_pub = Path(temporary) / "key.pub", Path(temporary) / "cert.pub"
            key_path.write_bytes(private_key)
            cert_path.write_bytes(certificate)
            if self._openssl(["pkey", "-in", str(key_path), "-pubout", "-out", str(key_pub)], check=False).returncode:
                return False
            if self._openssl(["x509", "-in", str(cert_path), "-pubkey", "-noout", "-out", str(cert_pub)], check=False).returncode:
                return False
            return hmac.compare_digest(key_pub.read_bytes(), cert_pub.read_bytes())

    def restore_federation_backup(self, source: Path, password: str, *, require_identity: bool = False) -> dict[str, Any]:
        payload = source.read_bytes()
        minimum = len(BACKUP_MAGIC) + 16 + 16 + 32
        if len(payload) < minimum or not payload.startswith(BACKUP_MAGIC):
            raise ClusterError("不是有效的 Lun 联邦备份")
        offset = len(BACKUP_MAGIC)
        salt, iv, cipher, tag = payload[offset:offset + 16], payload[offset + 16:offset + 32], payload[offset + 32:-32], payload[-32:]
        material = hashlib.pbkdf2_hmac("sha256", password.encode(), salt, BACKUP_KDF_ITERATIONS, 64)
        if not hmac.compare_digest(tag, hmac.new(material[32:], payload[:-32], hashlib.sha256).digest()):
            raise ClusterError("备份口令错误或文件已损坏")
        with tempfile.TemporaryDirectory(dir=self.module) as temporary:
            directory, cipher_path, archive = Path(temporary), Path(temporary) / "cipher", Path(temporary) / "archive.tar.gz"
            cipher_path.write_bytes(cipher)
            self._run([shutil.which("openssl") or "openssl", "enc", "-d", "-aes-256-cbc", "-K", material[:32].hex(), "-iv", iv.hex(), "-in", str(cipher_path), "-out", str(archive)])
            with tarfile.open(archive, "r:gz") as tar:
                members = tar.getmembers()
                allowed = {"config.json", "manifest.json", "data/cluster.db", "pki/federation-root.crt",
                           "pki/federation-node.crt", "pki/federation-root.key", "pki/federation-node.key"}
                names = [member.name for member in members]
                if len(names) != len(set(names)) or any(not member.isfile() or member.name not in allowed for member in members):
                    raise ClusterError("联邦备份包含不安全内容")
                contents = {member.name: tar.extractfile(member).read() for member in members}  # type: ignore[union-attr]
            if "manifest.json" not in contents or "data/cluster.db" not in contents:
                raise ClusterError("联邦备份缺少清单或数据库")
            manifest = json.loads(contents["manifest.json"].decode("utf-8"))
            if int(manifest.get("format", 0)) != 3 or int(manifest.get("api_version", 0)) > API_VERSION:
                raise ClusterError("备份来自更高版本")
            kind = str(manifest.get("kind", ""))
            if kind not in {"identity", "federation-data"}:
                raise ClusterError("联邦备份类型无效")
            identity = kind == "identity"
            if require_identity and not identity:
                raise ClusterError("identity-restore 只接受完整身份备份，拒绝 federation-data")
            expected = {"manifest.json", "data/cluster.db"} if not identity else allowed
            if set(contents) != expected:
                raise ClusterError("联邦备份成员与备份类型不匹配")
            source_db = directory / "source.db"
            source_db.write_bytes(contents["data/cluster.db"])
            checker = sqlite3.connect(f"file:{source_db.resolve().as_posix()}?mode=ro", uri=True)
            checker.row_factory = sqlite3.Row
            try:
                if checker.execute("PRAGMA integrity_check").fetchone()[0] != "ok":
                    raise ClusterError("联邦备份数据库完整性检查失败")
                source_events = [{key: row[key] for key in (
                    "event_id", "author_id", "author_seq", "prev_hash", "lamport", "type", "entity_key",
                    "payload", "created_at", "signature"
                )} for row in checker.execute("SELECT * FROM federation_events ORDER BY author_id,author_seq")]
            except sqlite3.Error as exc:
                raise ClusterError("联邦备份数据库结构无效") from exc
            finally:
                checker.close()
            backup_id = str(manifest.get("node_id", ""))
            backup_cluster = str(manifest.get("cluster_id", ""))
            current = self.load_config()
            current_id = str(self.load_config().get("node_id", ""))
            current_cluster = str(current.get("cluster_id", ""))
            if not identity and current_cluster and current_cluster != backup_cluster:
                raise ClusterError("联邦备份 cluster_id 与目标不一致")
            online = self.db.connection.execute("SELECT 1 FROM nodes WHERE id=? AND state='online'", (backup_id,)).fetchone()
            if identity and backup_id != current_id and online:
                raise ClusterError("拒绝恢复：同一联邦身份仍显示在线")
            checkpoint = directory / "checkpoint.db"
            destination = sqlite3.connect(checkpoint)
            try:
                self.db.connection.backup(destination)
            finally:
                destination.close()
            config_bytes = self.config_path.read_bytes() if self.config_path.is_file() else None
            identity_names = ("federation-root.crt", "federation-node.crt", "federation-root.key", "federation-node.key")
            old_identity = {name: (self.pki / name).read_bytes() for name in identity_names if (self.pki / name).is_file()}
            try:
                if not identity:
                    accepted = self.federation_import_events(source_events)
                    return {"manifest": manifest, "identity_restored": False, "accepted": accepted}
                config = json.loads(contents["config.json"].decode("utf-8"))
                if config.get("mode") != "federation" or config.get("node_id") != backup_id or config.get("cluster_id") != backup_cluster:
                    raise ClusterError("身份备份配置与清单不一致")
                root = contents["pki/federation-root.crt"]
                node = contents["pki/federation-node.crt"]
                self.validate_federation_certificates(backup_id, root.decode("utf-8"), node.decode("utf-8"))
                if not self._private_key_matches_certificate(contents["pki/federation-root.key"], root) \
                        or not self._private_key_matches_certificate(contents["pki/federation-node.key"], node):
                    raise ClusterError("身份备份私钥与证书不匹配")
                self.replace_database(source_db)
                atomic_write(self.config_path, contents["config.json"], 0o600)
                self.pki.mkdir(parents=True, exist_ok=True)
                for name in identity_names:
                    atomic_write(self.pki / name, contents[f"pki/{name}"], 0o600 if name.endswith(".key") else 0o644)
            except Exception:
                self._restore_database_checkpoint(checkpoint, config_bytes)
                for name in identity_names:
                    path = self.pki / name
                    if name in old_identity:
                        atomic_write(path, old_identity[name], 0o600 if name.endswith(".key") else 0o644)
                    else:
                        path.unlink(missing_ok=True)
                raise
        self.secure_files()
        return {"manifest": manifest, "identity_restored": identity}

    def restore_identity_backup(self, source: Path, password: str) -> dict[str, Any]:
        return self.restore_federation_backup(source, password, require_identity=True)


def print_nodes(rows: list[dict[str, Any]]) -> None:
    headers = ("编号", "状态", "类型", "地区", "地址", "备注", "快照")
    values: list[tuple[str, ...]] = []
    place_labels = numbered_place_labels(rows)
    for row in rows:
        hosts = order_public_hosts(
            row.get("endpoint_hosts", []) if isinstance(row.get("endpoint_hosts"), list) else [],
            str(row.get("endpoint_host", "")),
        )
        addresses = " / ".join(f"{uri_host(host)}:{row['endpoint_port']}" for host in hosts)
        values.append((
            f"{int(row.get('number', len(values) + 1)):02d}", STATE_NAMES_ZH.get(row["state"], "异常"),
            {"master": "主机", "child": "子机", "federation": "对等节点",
             "legacy-candidate": "未验证候选"}.get(str(row["role"]), "未知"),
            place_labels.get(str(row.get("id", "")), chinese_place(row)),
            addresses or "-", row["remark"] or "-",
            iso_time(row["snapshot_at"]),
        ))
    widths = [display_width(item) for item in headers]
    for row in values:
        widths = [max(old, display_width(item)) for old, item in zip(widths, row)]
    print("  ".join(display_pad(item, width) for item, width in zip(headers, widths)))
    for row in values:
        print("  ".join(display_pad(item, width) for item, width in zip(row, widths)))


def terminal_color(text: str, color: str, *, stream: Any = sys.stdout) -> str:
    if getattr(stream, "isatty", lambda: False)():
        return f"\033[{color}m{text}\033[0m"
    return text


def _peer_common_name(handler: http.server.BaseHTTPRequestHandler) -> str:
    with contextlib.suppress(AttributeError, TypeError, ValueError, ssl.SSLError):
        certificate = handler.connection.getpeercert()  # type: ignore[attr-defined]
        for group in certificate.get("subject", ()):
            for key, value in group:
                if key == "commonName":
                    return value
    return ""


class ClusterHandler(http.server.BaseHTTPRequestHandler):
    server_version = "FHLUN-Cluster/1"

    @property
    def cluster(self) -> Cluster:
        return self.server.cluster  # type: ignore[attr-defined]

    def _body(self) -> dict[str, Any]:
        try:
            length = int(self.headers.get("Content-Length", "0"))
        except ValueError as exc:
            raise ClusterError("请求长度无效") from exc
        if length < 0 or length > MAX_BODY:
            raise ClusterError("请求超过大小限制")
        try:
            value = json.loads(self.rfile.read(length).decode("utf-8")) if length else {}
        except (UnicodeDecodeError, json.JSONDecodeError) as exc:
            raise ClusterError("请求 JSON 无效") from exc
        if not isinstance(value, dict):
            raise ClusterError("请求正文必须是 JSON 对象")
        return value

    def _reply(self, status: int, value: dict[str, Any]) -> bool:
        payload = json.dumps(value, ensure_ascii=False, separators=(",", ":")).encode()
        try:
            self.send_response(status)
            self.send_header("Content-Type", "application/json; charset=utf-8")
            self.send_header("Content-Length", str(len(payload)))
            self.send_header("Cache-Control", "no-store")
            self.send_header("X-Content-Type-Options", "nosniff")
            self.end_headers()
            self.wfile.write(payload)
            self.wfile.flush()
            return True
        except (BrokenPipeError, ConnectionResetError, ssl.SSLError, OSError):
            # The join transaction may already be committed when an older client
            # gives up waiting.  Do not attempt a second response on a dead TLS
            # stream; join-status can recover the signed transaction safely.
            self.close_connection = True
            return False

    def _require_peer(self) -> str:
        common_name = _peer_common_name(self)
        if not re.fullmatch(r"[0-9a-f]{32}", common_name):
            raise ClusterError("需要有效的集群客户端证书")
        config = self.cluster.load_config()
        if config.get("mode") == "federation":
            row = self.cluster.db.connection.execute(
                "SELECT revoked_at FROM federation_keys WHERE node_id=?", (common_name,)
            ).fetchone()
            if not row or int(row["revoked_at"]):
                raise ClusterError("该证书不是活动联邦成员")
            return common_name
        if config.get("role") == "child":
            pending = config.get("pending_controller") if isinstance(config.get("pending_controller"), dict) else {}
            pending_valid = (
                common_name == pending.get("id")
                and int(pending.get("expires_at", 0)) >= utc_now()
            )
            if common_name != config.get("controller_id") and not pending_valid:
                raise ClusterError("该证书不是当前主 VPS")
        elif config.get("role") == "master":
            row = self.cluster.node(common_name)
            if row["role"] != "child":
                raise ClusterError("该证书不是已授权子 VPS")
        else:
            raise ClusterError("集群角色无效")
        return common_name

    def do_GET(self) -> None:  # noqa: N802
        try:
            parsed = urllib.parse.urlsplit(self.path)
            if parsed.path == "/v1/federation/membership-status":
                query = urllib.parse.parse_qs(parsed.query)
                node_id = query.get("node_id", [""])[0]
                nonce = query.get("nonce", [""])[0]
                plan = self.cluster.federation_cleanup_plan(node_id)
                proof = self.cluster.membership_status_proof(node_id, nonce)
                self._reply(200, {"ok": True, "status": plan, "proof": proof})
                return
            if parsed.path == "/v1/federation/bootstrap" and self.cluster.is_federation():
                token = urllib.parse.parse_qs(parsed.query).get("token", [""])[0]
                digest = hashlib.sha256(token.encode()).hexdigest()
                row = self.cluster.db.connection.execute("SELECT * FROM join_tokens WHERE token_hash=?", (digest,)).fetchone()
                if not row or row["used_at"] or row["expires_at"] < utc_now():
                    raise ClusterError("一次性加入令牌无效或已过期")
                self._reply(200, {"ok": True, "bundle": self.cluster.federation_public_bundle()})
                return
            if parsed.path == "/v1/bootstrap/csr":
                self._bootstrap_csr(parsed)
                return
            self._require_peer()
            if parsed.path == "/v1/federation/manifest" and self.cluster.is_federation():
                self._reply(200, {"ok": True, "manifest": self.cluster.federation_manifest()})
            elif parsed.path == "/v1/federation/events" and self.cluster.is_federation():
                query = urllib.parse.parse_qs(parsed.query)
                manifest = json.loads(query.get("manifest", ["{}"])[0])
                self._reply(200, {"ok": True, "manifest": self.cluster.federation_manifest(), "events": self.cluster.federation_events_since(manifest)})
            elif parsed.path == "/v1/status":
                self._reply(200, {"ok": True, "status": self.cluster.local_status()})
            elif parsed.path == "/v1/snapshot":
                query = urllib.parse.parse_qs(parsed.query)
                profile = query.get("profile", ["legacy"])[0]
                self._reply(200, {"ok": True, "snapshot": self.cluster.local_snapshot(profile)})
            else:
                self._reply(404, {"ok": False, "error": "not found"})
        except ClusterError as exc:
            self._reply(403, {"ok": False, "error": str(exc)})
        except Exception as exc:
            sys.stderr.write(f"cluster GET failed: {exc}\n")
            self._reply(500, {"ok": False, "error": "internal error"})
        finally:
            self.cluster.close()

    def do_POST(self) -> None:  # noqa: N802
        try:
            parsed = urllib.parse.urlsplit(self.path)
            body = self._body()
            if parsed.path == "/v1/bootstrap/complete":
                self._bootstrap_complete(body)
                return
            if parsed.path == "/v1/federation/join" and self.cluster.is_federation():
                token = str(body.get("token", ""))
                bundle = body.get("bundle") if isinstance(body.get("bundle"), dict) else {}
                transaction = body.get("transaction") if isinstance(body.get("transaction"), dict) else {}
                accepted = self.cluster.accept_federation_join(token, bundle, transaction)
                self._reply(200, {"ok": True, "transaction_id": accepted["transaction_id"],
                                  "bundle": accepted["bundle"]})
                # Importing the peer changes the accepted client CA set.  Reload
                # the TLS listener after the response has been sent so the new
                # member can use mTLS without a separate manual restart.
                self.server.restart_requested = True  # type: ignore[attr-defined]
                return
            if parsed.path == "/v1/federation/join-status" and self.cluster.is_federation():
                token = str(body.get("token", ""))
                transaction = body.get("transaction") if isinstance(body.get("transaction"), dict) else {}
                status = self.cluster.federation_join_status(token, transaction)
                self._reply(200, {"ok": True, **status})
                return
            peer = self._require_peer()
            if parsed.path == "/v1/federation/probe" and self.cluster.is_federation():
                if set(body) != {"candidate_id", "nonce"}:
                    raise ClusterError("federation probe accepts only candidate_id and nonce")
                vote = self.cluster.probe_vote_for_member(
                    str(body.get("candidate_id", "")), str(body.get("nonce", "")), peer
                )
                self._reply(200, {"ok": True, "vote": vote})
            elif parsed.path == "/v1/federation/events" and self.cluster.is_federation():
                events = body.get("events") if isinstance(body.get("events"), list) else []
                accepted = self.cluster.federation_import_events(events)
                refreshed = 0
                if accepted and any(str(event.get("type", "")) in {
                        "member.upsert", "member.revoke", "revocation.proof", "node.metadata"
                } for event in events if isinstance(event, dict)):
                    refreshed = len(self.cluster.refresh_profiles())
                self._reply(200, {"ok": True, "accepted": accepted, "refreshed": refreshed})
            elif parsed.path == "/v1/federation/snapshot" and self.cluster.is_federation():
                snapshot = body.get("snapshot") if isinstance(body.get("snapshot"), dict) else {}
                status = snapshot.get("status") if isinstance(snapshot.get("status"), dict) else {}
                if status.get("node_id") != peer:
                    relay = body.get("relay") if isinstance(body.get("relay"), dict) else {}
                    if set(relay) != {"batch_id", "deadline"} \
                            or not re.fullmatch(r"[0-9a-f]{32}", str(relay.get("batch_id", ""))):
                        raise ClusterError("订阅快照节点身份不匹配")
                    try:
                        relay_deadline = int(relay.get("deadline", 0))
                    except (TypeError, ValueError) as exc:
                        raise ClusterError("订阅快照中继期限无效") from exc
                    if relay_deadline < utc_now() or relay_deadline > utc_now() + FEDERATION_FANOUT_TTL + 30:
                        raise ClusterError("订阅快照中继批次无效或已过期")
                try:
                    self.cluster.record_federation_snapshot(snapshot)
                except ClusterError as exc:
                    if "回放旧版订阅快照" in str(exc):
                        self._reply(200, {"ok": True, "refreshed": 0, "stale": True})
                        return
                    raise
                refreshed = len(self.cluster.refresh_profiles())
                self._reply(200, {"ok": True, "refreshed": refreshed})
            elif parsed.path == "/v1/events/snapshot":
                if self.cluster.load_config().get("role") != "master":
                    raise ClusterError("当前节点不是主 VPS")
                snapshot = body.get("snapshot", {})
                status = snapshot.get("status", {}) if isinstance(snapshot, dict) else {}
                if status.get("node_id") != peer:
                    raise ClusterError("订阅快照节点身份不匹配")
                self.cluster.record_snapshot(snapshot)
                self.cluster.refresh_profiles(
                    str(snapshot.get("profile_key", "legacy")), sync_master_state=False
                )
                self._reply(200, {"ok": True})
            elif parsed.path == "/v1/events/usage":
                if self.cluster.load_config().get("role") != "master":
                    raise ClusterError("当前节点不是主 VPS")
                report = body.get("report") if isinstance(body.get("report"), dict) else {}
                node_id = report.get("node_id", peer)
                if node_id != peer:
                    raise ClusterError("流量上报节点身份不匹配")
                changed = self.cluster.record_usage(
                    node_id, str(report.get("device_uuid", "")), str(report.get("epoch", "")),
                    int(report.get("uplink", 0)), int(report.get("downlink", 0)),
                    int(report.get("month_uplink", 0)), int(report.get("month_downlink", 0)),
                    int(report.get("sequence", 0)),
                )
                totals = self.cluster.global_usage(str(report.get("device_uuid", "")), str(report.get("epoch", "")))
                self._reply(200, {"ok": True, "accepted": changed, "totals": totals})
            elif parsed.path == "/v1/action":
                result = execute_action(self.cluster, body, peer)
                self._reply(200, {"ok": True, "result": result})
                action_result = result.get("result") if isinstance(result.get("result"), dict) else {}
                if action_result.get("restart_required"):
                    self.server.restart_requested = True  # type: ignore[attr-defined]
            else:
                self._reply(404, {"ok": False, "error": "not found"})
        except ClusterError as exc:
            self._reply(400, {"ok": False, "error": str(exc)})
        except Exception as exc:
            sys.stderr.write(f"cluster POST failed: {exc}\n")
            self._reply(500, {"ok": False, "error": "internal error"})
        finally:
            self.cluster.close()

    def _bootstrap_csr(self, parsed: urllib.parse.SplitResult) -> None:
        config = self.cluster.load_config()
        if config.get("role") != "child":
            raise ClusterError("只有子 VPS 可以生成加入地址")
        token = urllib.parse.parse_qs(parsed.query).get("token", [""])[0]
        digest = hashlib.sha256(token.encode()).hexdigest()
        row = self.cluster.db.connection.execute(
            "SELECT * FROM join_tokens WHERE token_hash=?", (digest,)
        ).fetchone()
        if not row or row["used_at"] or row["expires_at"] < utc_now():
            raise ClusterError("一次性加入令牌无效或已过期")
        csr = (self.cluster.pki / "node.csr").read_text(encoding="utf-8")
        self._reply(200, {"ok": True, "node_id": config["node_id"], "csr": csr,
                          "status": self.cluster.local_status()})

    def _bootstrap_complete(self, body: dict[str, Any]) -> None:
        config = self.cluster.load_config()
        if config.get("role") != "child":
            raise ClusterError("只有子 VPS 可以完成配对")
        was_paired = bool(config.get("paired"))
        token = str(body.get("token", ""))
        cluster_id = str(body.get("cluster_id", ""))
        controller_id = str(body.get("controller_id", ""))
        if not re.fullmatch(r"[0-9a-f]{32}", cluster_id) or not re.fullmatch(r"[0-9a-f]{32}", controller_id):
            raise ClusterError("主 VPS 身份无效")
        ca = str(body.get("ca_certificate", ""))
        certificate = str(body.get("node_certificate", ""))
        controller = body.get("controller") if isinstance(body.get("controller"), dict) else {}
        identity = body.get("identity") if isinstance(body.get("identity"), dict) else {}
        server_number = int(identity.get("server_number", config.get("server_number", 1)))
        location = identity.get("location") if isinstance(identity.get("location"), dict) else config.get("location", {})
        place = safe_label(str(identity.get("place", "")), 48)
        if server_number < 1:
            raise ClusterError("主 VPS 下发的服务器编号无效")
        host = normalize_host(str(controller.get("host", "")))
        port = int(controller.get("port", 0))
        if not valid_port(port) or "BEGIN CERTIFICATE" not in ca or "BEGIN CERTIFICATE" not in certificate:
            raise ClusterError("配对证书或主 VPS 地址无效")
        self.cluster.consume_join_token(token)
        if (self.cluster.pki / "node.crt").is_file():
            shutil.copy2(self.cluster.pki / "node.crt", self.cluster.pki / "node-serving.crt")
        atomic_write(self.cluster.pki / "cluster-ca.crt", ca, 0o644)
        atomic_write(self.cluster.pki / "node.crt", certificate, 0o644)
        config.update({
            "cluster_id": cluster_id, "controller_id": controller_id,
            "controller_host": host, "controller_port": port, "paired": True,
            "server_number": server_number,
            "location": self.cluster.normalize_identity_location(location),
            "place": place,
        })
        self.cluster.save_config(config)
        self.cluster.apply_local_identity(server_number, config["location"], place)
        rebuild_error = ""
        try:
            self.cluster.rebuild_identity_subscriptions()
        except ClusterError as exc:
            rebuild_error = str(exc)
        self.cluster.db.audit("cluster.repaired" if was_paired else "cluster.paired", controller_id, f"{host}:{port}")
        self._reply(200, {"ok": True, "snapshot": self.cluster.local_snapshot(),
                          "identity_rebuild_error": rebuild_error, "restart_required": True})
        self.server.restart_requested = True  # type: ignore[attr-defined]

    def log_message(self, fmt: str, *args: Any) -> None:
        # Paths can contain one-time join tokens; never write request paths.
        sys.stderr.write(f"cluster {self.client_address[0]} {args[1] if len(args) > 1 else ''}\n")


class ThreadingClusterServer(http.server.ThreadingHTTPServer):
    daemon_threads = True
    allow_reuse_address = True
    request_queue_size = 64

    def __init__(self, server_address: tuple[str, int], handler: type[http.server.BaseHTTPRequestHandler],
                 tls_context: ssl.SSLContext | None = None):
        host, port = server_address
        self.tls_context = tls_context
        self.dual_stack = host in {"", "0.0.0.0", "::"} and socket.has_ipv6
        if self.dual_stack:
            self.address_family = socket.AF_INET6
            server_address = ("::", port)
        super().__init__(server_address, handler)

    def server_bind(self) -> None:
        if self.address_family == socket.AF_INET6:
            with contextlib.suppress(OSError):
                self.socket.setsockopt(socket.IPPROTO_IPV6, socket.IPV6_V6ONLY, 0)
        super().server_bind()

    def process_request_thread(self, request: socket.socket,
                               client_address: tuple[Any, ...]) -> None:
        if self.tls_context is None:
            super().process_request_thread(request, client_address)
            return
        tls_request: ssl.SSLSocket | None = None
        try:
            request.settimeout(TLS_HANDSHAKE_TIMEOUT)
            tls_request = self.tls_context.wrap_socket(request, server_side=True)
            tls_request.settimeout(None)
            super().process_request_thread(tls_request, client_address)
        except (OSError, ssl.SSLError, TimeoutError):
            self.shutdown_request(tls_request or request)


def allow_legacy_federation_ca(context: ssl.SSLContext) -> ssl.SSLContext:
    """Keep normal CA verification while accepting pre-3.14 Lun roots without keyUsage."""
    strict = getattr(ssl, "VERIFY_X509_STRICT", 0)
    if strict:
        context.verify_flags &= ~strict
    return context


def federation_client_context(*, cafile: str | None = None,
                              cadata: str | None = None) -> ssl.SSLContext:
    """Build a verified client context without Python 3.14's strict legacy-CA rejection."""
    context = ssl.SSLContext(ssl.PROTOCOL_TLS_CLIENT)
    context.check_hostname = False
    context.verify_mode = ssl.CERT_REQUIRED
    context.minimum_version = ssl.TLSVersion.TLSv1_2
    context.load_verify_locations(cafile=cafile, cadata=cadata)
    return allow_legacy_federation_ca(context)


def federation_server_context(cluster: Cluster, *, dynamic: bool = True) -> ssl.SSLContext:
    context = allow_legacy_federation_ca(ssl.SSLContext(ssl.PROTOCOL_TLS_SERVER))
    context.minimum_version = ssl.TLSVersion.TLSv1_2
    context.load_cert_chain(
        str(cluster.pki / "federation-node.crt"), str(cluster.pki / "federation-node.key")
    )
    context.load_verify_locations(cafile=str(cluster.federation_trust_bundle()))
    context.verify_mode = ssl.CERT_OPTIONAL
    if dynamic:
        def reload_trust(tls_socket: ssl.SSLSocket, _server_name: str | None,
                         _initial: ssl.SSLContext) -> None:
            # The callback runs after ClientHello but before client-certificate
            # verification, so newly signed member roots take effect without a
            # process restart or a brief federation outage.
            tls_socket.context = federation_server_context(cluster, dynamic=False)

        context.set_servername_callback(reload_trust)
    return context


def server_context(cluster: Cluster) -> ssl.SSLContext:
    if cluster.is_federation():
        return federation_server_context(cluster)
    context = ssl.SSLContext(ssl.PROTOCOL_TLS_SERVER)
    context.minimum_version = ssl.TLSVersion.TLSv1_2
    context.load_cert_chain(str(cluster.pki / "node.crt"), str(cluster.pki / "node.key"))
    ca = cluster.pki / "cluster-ca.crt"
    if ca.exists():
        context.load_verify_locations(cafile=str(ca))
        context.verify_mode = ssl.CERT_OPTIONAL
    else:
        context.verify_mode = ssl.CERT_NONE
    return context


def serve(cluster: Cluster) -> None:
    config = cluster.load_config()
    if not config.get("enabled") and config.get("retired_node_id") and config.get("revoked_at"):
        return
    if not config.get("enabled") or (config.get("role") not in {"master", "child"} and not cluster.is_federation()):
        raise ClusterError("服务器联动模块尚未启用")
    bind = config.get("bind", "0.0.0.0")
    port = int(config.get("internal_port", 0))
    if not valid_port(port):
        raise ClusterError("服务器联动监听端口无效")
    if cluster.is_federation():
        revocation = cluster.check_self_revocation()
        if revocation.get("cleaned"):
            return
    # A re-pair may change node.crt while the old TLS listener is still alive.
    # The compatibility fingerprint is only needed until this fresh process starts.
    (cluster.pki / "node-serving.crt").unlink(missing_ok=True)
    server = ThreadingClusterServer((bind, port), ClusterHandler, server_context(cluster))
    server.cluster = cluster  # type: ignore[attr-defined]
    server.restart_requested = False  # type: ignore[attr-defined]
    stopping = threading.Event()

    def stop(*_: Any) -> None:
        stopping.set()
        threading.Thread(target=server.shutdown, daemon=True).start()

    signal.signal(signal.SIGTERM, stop)
    signal.signal(signal.SIGINT, stop)

    def watch_restart() -> None:
        while not stopping.wait(0.5):
            if server.restart_requested:  # type: ignore[attr-defined]
                time.sleep(0.5)
                stop()
                return

    threading.Thread(target=watch_restart, daemon=True).start()

    def initial_federation_maintenance() -> None:
        with contextlib.suppress(ClusterError, OSError, sqlite3.Error):
            if cluster.is_federation():
                reconcile_federation_endpoint(cluster)
            cluster.subscription_catchup()

    threading.Thread(target=initial_federation_maintenance, daemon=True).start()

    def usage_loop() -> None:
        while not stopping.is_set():
            with contextlib.suppress(ClusterError, OSError, sqlite3.Error):
                cluster.push_usage_events()
            if stopping.wait(30):
                return

    threading.Thread(target=usage_loop, daemon=True).start()
    try:
        server.serve_forever(poll_interval=0.5)
    finally:
        server.server_close()
    if server.restart_requested:  # type: ignore[attr-defined]
        raise SystemExit(RESTART_EXIT_CODE)


def bootstrap_request(join: dict[str, Any], method: str, path: str,
                      body: dict[str, Any] | None = None,
                      timeout: int | None = None) -> dict[str, Any]:
    timeout = JOIN_REQUEST_TIMEOUT if timeout is None and path == "/v1/federation/join" \
        else int(timeout or BOOTSTRAP_TIMEOUT)
    context = ssl._create_unverified_context()  # fingerprint pinning below is the trust decision
    connection = http.client.HTTPSConnection(join["host"], join["port"], context=context, timeout=timeout)
    try:
        connection.connect()
        certificate = connection.sock.getpeercert(binary_form=True)  # type: ignore[union-attr]
        fingerprint = hashlib.sha256(certificate).hexdigest()
        if not hmac.compare_digest(fingerprint, join["fingerprint"]):
            raise ClusterError("目标 VPS TLS 指纹与加入地址不一致")
        payload = json.dumps(body, ensure_ascii=False).encode() if body is not None else None
        headers = {"Content-Type": "application/json"} if payload is not None else {}
        connection.request(method, path, body=payload, headers=headers)
        response = connection.getresponse()
        data = response.read(MAX_BODY + 1)
    except ClusterError:
        raise
    except (OSError, ssl.SSLError, TimeoutError, http.client.HTTPException) as exc:
        raise FederationTransportError(f"联邦加入通信失败：{exc}") from exc
    finally:
        connection.close()
    if len(data) > MAX_BODY:
        raise ClusterError("子 VPS 响应超过大小限制")
    try:
        result = json.loads(data.decode("utf-8"))
    except (UnicodeDecodeError, json.JSONDecodeError) as exc:
        raise ClusterError("子 VPS 返回了无效响应") from exc
    if response.status >= 400 or not result.get("ok"):
        raise ClusterError(result.get("error") or f"子 VPS 返回 HTTP {response.status}")
    return result


def mutual_request(cluster: Cluster, host: str, port: int, method: str, path: str,
                   body: dict[str, Any] | None = None, timeout: int = 30) -> dict[str, Any]:
    if cluster.is_federation():
        context = federation_client_context(cafile=str(cluster.federation_trust_bundle()))
        certificate, key = cluster.pki / "federation-node.crt", cluster.pki / "federation-node.key"
    else:
        context = ssl.create_default_context(ssl.Purpose.SERVER_AUTH, cafile=str(cluster.pki / "cluster-ca.crt"))
        certificate, key = cluster.pki / "node.crt", cluster.pki / "node.key"
    context.check_hostname = False
    context.minimum_version = ssl.TLSVersion.TLSv1_2
    context.load_cert_chain(str(certificate), str(key))
    connection = http.client.HTTPSConnection(host, int(port), context=context, timeout=timeout)
    payload = json.dumps(body, ensure_ascii=False).encode() if body is not None else None
    headers = {"Content-Type": "application/json"} if payload is not None else {}
    try:
        connection.request(method, path, body=payload, headers=headers)
        response = connection.getresponse()
        data = response.read(MAX_BODY + 1)
    except (OSError, ssl.SSLError, TimeoutError) as exc:
        raise FederationTransportError(f"federation transport failed: {exc}") from exc
    finally:
        connection.close()
    if len(data) > MAX_BODY:
        raise ClusterError("远端响应超过大小限制")
    try:
        result = json.loads(data.decode("utf-8"))
    except (UnicodeDecodeError, json.JSONDecodeError) as exc:
        raise ClusterError("远端返回了无效 JSON") from exc
    if response.status >= 400 or not result.get("ok"):
        raise ClusterError(result.get("error") or f"远端返回 HTTP {response.status}")
    return result


def membership_status_request(cluster: Cluster, peer: dict[str, Any], node_id: str,
                              nonce: str, timeout: int = 15) -> dict[str, Any]:
    """Fetch only the public revocation proof without presenting a client certificate."""
    peer_id = str(peer.get("id", ""))
    key = cluster.db.connection.execute(
        "SELECT root_certificate,revoked_at FROM federation_keys WHERE node_id=?", (peer_id,)
    ).fetchone()
    if not key or int(key["revoked_at"]) or str(peer.get("state", "")) in {
            "legacy-unverified", "revoked", "removed"}:
        raise ClusterError("membership-status peer is not an active trusted member")
    context = federation_client_context(cadata=str(key["root_certificate"]))
    host, port = str(peer.get("endpoint_host", "")), int(peer.get("endpoint_port", 0))
    connection = http.client.HTTPSConnection(host, port, context=context, timeout=timeout)
    path = "/v1/federation/membership-status?node_id=" + urllib.parse.quote(node_id) \
        + "&nonce=" + urllib.parse.quote(nonce)
    try:
        connection.request("GET", path)
        response = connection.getresponse()
        data = response.read(MAX_BODY + 1)
    except (OSError, ssl.SSLError, TimeoutError) as exc:
        raise FederationTransportError(f"membership-status transport failed: {exc}") from exc
    finally:
        connection.close()
    if len(data) > MAX_BODY:
        raise ClusterError("membership-status response exceeds size limit")
    try:
        result = json.loads(data.decode("utf-8"))
    except (UnicodeDecodeError, json.JSONDecodeError) as exc:
        raise ClusterError("membership-status returned invalid JSON") from exc
    if response.status >= 400 or not isinstance(result, dict) or not result.get("ok"):
        raise ClusterError(str(result.get("error", "membership-status request failed")) if isinstance(result, dict)
                           else "membership-status request failed")
    return result


def federation_add_peer(cluster: Cluster, join_uri: str, remark: str = "") -> dict[str, Any]:
    if not cluster.is_federation():
        raise ClusterError("请先初始化或迁移为联邦模式")
    join = parse_join_uri(join_uri)
    token_hash = hashlib.sha256(join["token"].encode("utf-8")).hexdigest()
    pending = cluster.db.connection.execute(
        "SELECT * FROM federation_join_transactions WHERE direction='outgoing' AND token_hash=? "
        "AND status='remote-committed-local-pending' ORDER BY updated_at DESC LIMIT 1",
        (token_hash,),
    ).fetchone()
    if pending:
        transaction = json.loads(str(pending["transaction_payload"]))
        if transaction.get("responder_id") != join["node_id"]:
            raise ClusterError("待恢复配对事务与加入地址身份不一致")
        recovery = bootstrap_request(join, "POST", "/v1/federation/join-status", {
            "token": join["token"], "transaction": transaction,
        })
        if recovery.get("transaction_id") != transaction["transaction_id"] \
                or not isinstance(recovery.get("bundle"), dict):
            raise ClusterError("远端未返回匹配的待恢复配对事务")
        registered = cluster.import_federation_bundle(
            recovery["bundle"], pinned_identity_fingerprint=join["fingerprint"], allow_foreign_single=False
        )
        cluster.confirm_federation_member(recovery["bundle"], remark)
        cluster.save_outgoing_join_transaction(join["token"], transaction, recovery["bundle"], "committed")
        cluster.db.audit("federation.add-peer.recovered", str(join["node_id"]), remark)
        return {"node_id": registered["node_id"], "accepted": registered["accepted"],
                "transaction_id": transaction["transaction_id"], "recovered": True}
    remote = bootstrap_request(join, "GET", "/v1/federation/bootstrap?token=" + urllib.parse.quote(join["token"]))
    bundle = remote.get("bundle") if isinstance(remote.get("bundle"), dict) else {}
    if bundle.get("node_id") != join["node_id"]:
        raise ClusterError("加入地址与远端联邦身份不一致")
    cluster.validate_federation_bundle(bundle, pinned_identity_fingerprint=join["fingerprint"],
                                       allow_foreign_single=True)
    local = cluster.federation_public_bundle()
    transaction = cluster.create_join_transaction(local, str(bundle["node_id"]))
    remote_bundle: dict[str, Any] | None = None
    initial_error = ""
    try:
        response = bootstrap_request(join, "POST", "/v1/federation/join", {
            "token": join["token"], "bundle": local, "transaction": transaction,
        })
        if response.get("transaction_id") != transaction["transaction_id"] \
                or not isinstance(response.get("bundle"), dict):
            raise ClusterError("远端联邦配对响应缺少匹配的 transaction_id 或 bundle")
        remote_bundle = response["bundle"]
        registered = cluster.import_federation_bundle(
            remote_bundle, pinned_identity_fingerprint=join["fingerprint"], allow_foreign_single=False
        )
        cluster.confirm_federation_member(remote_bundle, remark)
    except ClusterError as exc:
        initial_error = str(exc)
        try:
            recovery = bootstrap_request(join, "POST", "/v1/federation/join-status", {
                "token": join["token"], "transaction": transaction,
            })
            if recovery.get("transaction_id") != transaction["transaction_id"] \
                    or not isinstance(recovery.get("bundle"), dict):
                raise ClusterError("远端未返回匹配的配对事务状态")
            remote_bundle = recovery["bundle"]
            registered = cluster.import_federation_bundle(
                remote_bundle, pinned_identity_fingerprint=join["fingerprint"], allow_foreign_single=False
            )
            cluster.confirm_federation_member(remote_bundle, remark)
        except ClusterError as recovery_error:
            cluster.save_outgoing_join_transaction(
                join["token"], transaction, remote_bundle, "remote-committed-local-pending"
            )
            raise ClusterError(
                "联邦配对未能在本机完成；已保留可恢复事务 " + transaction["transaction_id"]
                + "。首次错误：" + initial_error + "；状态恢复错误：" + str(recovery_error)
            ) from recovery_error
    cluster.save_outgoing_join_transaction(join["token"], transaction, remote_bundle, "committed")
    cluster.db.audit("federation.add-peer", str(bundle["node_id"]), remark)
    return {"node_id": registered["node_id"], "accepted": registered["accepted"],
            "transaction_id": transaction["transaction_id"], "recovered": bool(initial_error)}


def federation_sync(cluster: Cluster, node_id: str, *, attempts: int = 3,
                    coordinate_failures: bool = True, timeout: int = 30) -> dict[str, Any]:
    if not cluster.is_federation():
        raise ClusterError("当前不是联邦模式")
    node = cluster.node(node_id)
    trusted = cluster.db.connection.execute("SELECT revoked_at FROM federation_keys WHERE node_id=?", (node["id"],)).fetchone()
    if not trusted or int(trusted["revoked_at"]):
        raise ClusterError("旧迁移候选或已撤销节点必须重新显式配对后才能同步")
    last_error: FederationTransportError | None = None
    attempts = max(1, int(attempts))
    for attempt in range(attempts):
        try:
            local_manifest = cluster.federation_manifest()
            remote = mutual_request(
                cluster, str(node["endpoint_host"]), int(node["endpoint_port"]), "GET",
                "/v1/federation/events?manifest=" + urllib.parse.quote(json_dumps(local_manifest)),
                timeout=timeout,
            )
            received = cluster.federation_import_events(
                remote.get("events", []) if isinstance(remote.get("events"), list) else []
            )
            response = mutual_request(
                cluster, str(node["endpoint_host"]), int(node["endpoint_port"]), "POST",
                "/v1/federation/events", {"events": cluster.federation_events_since(remote.get("manifest", {}))},
                timeout=timeout,
            )
            cluster.record_transport_success(str(node["id"]))
            cluster.mark_endpoint_synced(str(node["id"]))
            return {"node_id": str(node["id"]), "received": received,
                    "accepted_by_peer": int(response.get("accepted", 0)), "attempts": attempt + 1}
        except FederationTransportError as exc:
            last_error = exc
    if coordinate_failures:
        failure = cluster.record_transport_failure(str(node["id"]))
        health = cluster._coordinate_after_failures(
            str(node["id"]), list(failure["failure_times"])[-3:]
        ) if failure["needs_probe"] else failure
        raise FederationTransportError(
            f"federation sync failed after {attempts} attempts; health={json_dumps(health)}; error={last_error}"
        ) from last_error
    raise FederationTransportError(
        f"federation sync failed after {attempts} attempts; error={last_error}"
    ) from last_error


def parallel_federation_sync(cluster: Cluster, node_ids: Iterable[str], *, attempts: int = 1,
                             coordinate_failures: bool = False,
                             timeout: int = 12) -> tuple[dict[str, Any], dict[str, str]]:
    """Synchronize a bounded peer set without sharing one SQLite connection across threads."""
    selected = list(dict.fromkeys(str(node_id) for node_id in node_ids))
    delivered: dict[str, Any] = {}
    failures: dict[str, str] = {}
    if not selected:
        return delivered, failures

    def sync_one(node_id: str) -> tuple[str, dict[str, Any]]:
        try:
            return node_id, federation_sync(
                cluster, node_id, attempts=attempts, coordinate_failures=coordinate_failures,
                timeout=timeout,
            )
        finally:
            cluster.db.close()

    with concurrent.futures.ThreadPoolExecutor(
            max_workers=min(FEDERATION_FANOUT, len(selected))) as executor:
        futures = {executor.submit(sync_one, node_id): node_id for node_id in selected}
        for future in concurrent.futures.as_completed(futures):
            node_id = futures[future]
            try:
                _, delivered[node_id] = future.result()
            except Exception as exc:
                failures[node_id] = str(exc)[-1000:]
    return delivered, failures


def parallel_federation_action(cluster: Cluster, node_ids: Iterable[str], action: str,
                               payload_for: Callable[[str], dict[str, Any]], *,
                               timeout: int = 30) -> tuple[dict[str, Any], dict[str, str]]:
    """Run one allow-listed action per peer with a fixed concurrency ceiling."""
    selected = list(dict.fromkeys(str(node_id) for node_id in node_ids))
    delivered: dict[str, Any] = {}
    failures: dict[str, str] = {}
    if not selected:
        return delivered, failures

    def send_one(node_id: str) -> tuple[str, dict[str, Any]]:
        try:
            return node_id, send_action(
                cluster, node_id, action, payload_for(node_id), timeout=timeout,
                coordinate_failures=False,
            )
        finally:
            cluster.db.close()

    with concurrent.futures.ThreadPoolExecutor(
            max_workers=min(FEDERATION_FANOUT, len(selected))) as executor:
        futures = {executor.submit(send_one, node_id): node_id for node_id in selected}
        for future in concurrent.futures.as_completed(futures):
            node_id = futures[future]
            try:
                _, delivered[node_id] = future.result()
            except Exception as exc:
                failures[node_id] = str(exc)[-1000:]
    return delivered, failures


def wait_for_federation_peer(cluster: Cluster, node_id: str, timeout: int = 90) -> dict[str, Any]:
    node = cluster.node(node_id)
    deadline = time.monotonic() + max(1, int(timeout))
    last_error = ""
    while time.monotonic() < deadline:
        try:
            response = mutual_request(
                cluster, str(node["endpoint_host"]), int(node["endpoint_port"]),
                "GET", "/v1/status", timeout=min(10, max(1, int(deadline - time.monotonic()))),
            )
            status = response.get("status") if isinstance(response.get("status"), dict) else {}
            if status.get("node_id") == node["id"]:
                return status
            last_error = "目标返回了其它节点身份"
        except ClusterError as exc:
            last_error = str(exc)
        time.sleep(min(2.0, max(0.1, deadline - time.monotonic())))
    raise FederationTransportError(f"等待联邦成员重载超时：{last_error or '无响应'}")


def federation_relay(cluster: Cluster, payload: dict[str, Any], source_peer: str) -> dict[str, Any]:
    """Relay one bounded fan-out layer. Targets never relay again in the same action."""
    if set(payload) != {"batch_id", "deadline", "node_ids"}:
        raise ClusterError("联邦中继只接受 batch_id、deadline 与 node_ids")
    batch_id = str(payload.get("batch_id", ""))
    if not re.fullmatch(r"[0-9a-f]{32}", batch_id):
        raise ClusterError("联邦中继批次号无效")
    try:
        deadline = int(payload.get("deadline", 0))
    except (TypeError, ValueError) as exc:
        raise ClusterError("联邦中继截止时间无效") from exc
    now = utc_now()
    if deadline < now or deadline > now + FEDERATION_FANOUT_TTL + 30:
        raise ClusterError("联邦中继批次已过期或有效期过长")
    raw_targets = payload.get("node_ids")
    if not isinstance(raw_targets, list) or len(raw_targets) > FEDERATION_FANOUT:
        raise ClusterError(f"每个联邦中继最多分发 {FEDERATION_FANOUT} 个成员")
    local_id = str(cluster.load_config().get("node_id", ""))
    targets: list[str] = []
    for value in raw_targets:
        row = cluster.node(str(value))
        node_id = str(row["id"])
        if node_id not in {local_id, source_peer} and node_id not in targets:
            targets.append(node_id)
    cache_key = f"federation.relay.{batch_id}"
    cached = cluster.db.setting(cache_key, "")
    if cached:
        with contextlib.suppress(json.JSONDecodeError):
            return {**json.loads(cached), "replayed": True}
    delivered, failures = parallel_federation_sync(
        cluster, targets, attempts=1, coordinate_failures=False
    )
    result = {"batch_id": batch_id, "source": source_peer,
              "delivered": sorted(delivered), "failures": failures, "replayed": False}
    cluster.db.set_setting(cache_key, json_dumps(result))
    cluster.db.audit("federation.relay", batch_id, f"ok={len(delivered)} failed={len(failures)}")
    return result


def federation_finalize_peer(cluster: Cluster, node_id: str,
                             progress: Callable[[str], None] | None = None) -> dict[str, Any]:
    """Finish pairing with one bounded 1→10→100 fan-out and one convergence pass."""
    emit = progress or (lambda _message: None)
    target = cluster.node(node_id)
    target_id = str(target["id"])
    replaced_legacy = cluster.reconcile_repaired_legacy_member(target_id)
    failures: dict[str, str] = {}
    warnings: dict[str, str] = {}

    emit("[1/6] 等待新成员联邦服务就绪……")
    wait_for_federation_peer(cluster, target_id, timeout=35)
    target_sync = federation_sync(
        cluster, target_id, attempts=1, coordinate_failures=False, timeout=12
    )

    emit("[2/6] 根据公网 IP 自动识别地区……")
    location: dict[str, str] = {}
    try:
        location = cluster.geolocate(target_id, timeout=6)
    except ClusterError as exc:
        warnings["location"] = "自动地区识别失败：" + str(exc)
        emit("提示：自动地区识别暂时失败，可稍后在地区设置中重试。")

    existing_rows = [row for row in cluster.trusted_federation_nodes()
                     if str(row["id"]) != target_id]
    existing_ids = [str(row["id"]) for row in existing_rows if str(row["state"]) == "online"]
    deferred_ids = [str(row["id"]) for row in existing_rows if str(row["state"]) != "online"]
    if deferred_ids:
        warnings["deferred_members"] = \
            f"{len(deferred_ids)} 个疑似离线成员未阻塞本轮，恢复后会自动补齐"
    roots = existing_ids[:FEDERATION_FANOUT]
    remainder = existing_ids[FEDERATION_FANOUT:FEDERATION_FANOUT * (FEDERATION_FANOUT + 1)]
    assignments = {root: remainder[index::len(roots)] if roots else []
                   for index, root in enumerate(roots)}
    overflow = existing_ids[FEDERATION_FANOUT * (FEDERATION_FANOUT + 1):]

    emit(f"[3/6] 有界广播信任：首层 {len(roots)} 个，中继 {len(remainder)} 个……")
    root_results, root_failures = parallel_federation_sync(
        cluster, roots, attempts=1, coordinate_failures=False
    )
    spread: dict[str, str] = {node_id: "direct" for node_id in root_results}
    failures.update({node_id: "广播失败：" + detail for node_id, detail in root_failures.items()})
    batch_id = uuid.uuid4().hex
    deadline = utc_now() + FEDERATION_FANOUT_TTL
    relay_roots = [node_id for node_id in roots if node_id in root_results and assignments[node_id]]
    relay_results, relay_failures = parallel_federation_action(
        cluster, relay_roots, "federation.relay",
        lambda relay_id: {"batch_id": batch_id, "deadline": deadline,
                          "node_ids": assignments[relay_id]}, timeout=45,
    )
    for relay_id, wrapper in relay_results.items():
        payload = _action_result_payload(wrapper)
        for delivered_id in payload.get("delivered", []):
            spread[str(delivered_id)] = f"relay:{short_id(relay_id)}"
        for failed_id, detail in payload.get("failures", {}).items():
            failures[str(failed_id)] = "中继广播失败：" + str(detail)
    failures.update({node_id: "中继执行失败：" + detail for node_id, detail in relay_failures.items()})
    if overflow:
        overflow_results, overflow_failures = parallel_federation_sync(
            cluster, overflow, attempts=1, coordinate_failures=False
        )
        spread.update({node_id: "overflow-direct" for node_id in overflow_results})
        failures.update({node_id: "补充广播失败：" + detail
                         for node_id, detail in overflow_failures.items()})

    emit("[4/6] 动态信任已生效，无需逐台重启联邦服务……")
    restart = {"mode": "dynamic-trust", "restarted": 0}

    emit("[5/6] 发布新成员身份和订阅快照……")
    identity: dict[str, Any] = {}
    snapshot_exchange: dict[str, Any] = {}
    try:
        identity = push_node_identity(
            cluster, target_id, propagate=False, publish_local=True
        )
        federation_sync(
            cluster, target_id, attempts=1, coordinate_failures=False, timeout=8
        )
        identity_payload = _action_result_payload(identity)
        target_snapshot = identity_payload.get("snapshot") \
            if isinstance(identity_payload.get("snapshot"), dict) else None
        target_delivered: list[str] = []
        target_delivery_failures: dict[str, str] = {}
        if target_snapshot:
            target_delivered, target_delivery_failures = deliver_federation_snapshots(
                cluster, ((peer_id, target_snapshot) for peer_id in existing_ids), timeout=5
            )
        source_snapshots, source_failures = fetch_federation_snapshots(
            cluster, [node_id for node_id in existing_ids if node_id in spread], timeout=5
        )
        source_delivered, source_delivery_failures = deliver_federation_snapshots(
            cluster, ((target_id, item) for item in source_snapshots.values()), timeout=5
        )
        snapshot_exchange = {
            "target_delivered": target_delivered,
            "target_failures": target_delivery_failures,
            "source_snapshots": sorted(source_snapshots),
            "source_failures": source_failures,
            "source_delivered": source_delivered,
            "source_delivery_failures": source_delivery_failures,
        }
        exchange_failures = {
            **target_delivery_failures, **source_failures, **source_delivery_failures,
        }
        if exchange_failures:
            warnings["snapshot_exchange"] = \
                f"{len(exchange_failures)} 项远端快照暂未送达，将在订阅刷新时继续补齐"
    except ClusterError as exc:
        failures[target_id] = "订阅快照补齐失败：" + str(exc)

    emit("[6/6] 单轮收敛并刷新聚合订阅……")
    convergence, convergence_failures = parallel_federation_sync(
        cluster, [*existing_ids, target_id], attempts=1, coordinate_failures=False
    )
    failures.update({node_id: "收敛检查失败：" + detail
                     for node_id, detail in convergence_failures.items()})
    profiles = cluster.refresh_profiles()
    return {
        "node_id": target_id, "target_sync": target_sync, "location": location,
        "deferred": deferred_ids,
        "spread": spread, "restart": restart, "identity": identity,
        "snapshot_exchange": snapshot_exchange,
        "convergence": {node_id: "ok" for node_id in convergence},
        "failures": failures, "warnings": warnings,
        "profiles": len(profiles), "replaced_legacy": replaced_legacy, "complete": not failures,
    }


def add_node(cluster: Cluster, join_uri: str, remark: str = "", expected_uuid: str = "") -> dict[str, Any]:
    config = cluster.load_config()
    if config.get("role") != "master" and not cluster.is_federation():
        raise ClusterError("只有主 VPS 可以添加子 VPS")
    join = parse_join_uri(join_uri)
    result = bootstrap_request(join, "GET", "/v1/bootstrap/csr?token=" + urllib.parse.quote(join["token"]))
    if result.get("node_id") != join["node_id"]:
        raise ClusterError("子 VPS 返回的节点身份与加入地址不一致")
    status = result.get("status") if isinstance(result.get("status"), dict) else {}
    if expected_uuid and status.get("uuid") != expected_uuid:
        raise ClusterError("目标 UUID 与子 VPS 当前 UUID 不一致，已拒绝加入")
    cluster.upsert_node(status, remark=remark, expected_uuid=expected_uuid)
    with contextlib.suppress(ClusterError):
        cluster.geolocate(join["node_id"])
    pending = cluster.node(join["node_id"])
    server_number = int(pending["server_number"])
    location = {key: pending[key] for key in ("country_code", "country", "region", "city", "provider")}
    place = cluster.identity_place(pending)
    node_certificate = cluster._sign_csr(str(result.get("csr", "")), join["node_id"], cluster.pki / f"issued-{join['node_id']}.crt")
    completion = bootstrap_request(join, "POST", "/v1/bootstrap/complete", {
        "token": join["token"], "cluster_id": config["cluster_id"], "controller_id": config["node_id"],
        "controller": {"host": config["public_host"], "port": config["public_port"]},
        "ca_certificate": (cluster.pki / "cluster-ca.crt").read_text(encoding="utf-8"),
        "node_certificate": node_certificate,
        "identity": {"server_number": server_number, "location": location, "place": place},
    })
    snapshot = completion.get("snapshot") if isinstance(completion.get("snapshot"), dict) else {}
    if snapshot:
        cluster.record_snapshot(snapshot)
    rebuild_error = str(completion.get("identity_rebuild_error") or "").strip()
    if rebuild_error:
        cluster.db.audit("identity.rebuild.pending", join["node_id"], rebuild_error[-2000:])
    else:
        cluster.mark_identity_synced(cluster.node(join["node_id"]))
    cluster.db.audit("node.add", join["node_id"], remark)
    return dict(cluster.node(join["node_id"]))


def sync_node(cluster: Cluster, node_id: str, profile: str = "legacy") -> dict[str, Any]:
    node = cluster.node(node_id)
    resolved_id = str(node["id"])
    try:
        push_node_identity(cluster, resolved_id)
        result = mutual_request(cluster, node["endpoint_host"], node["endpoint_port"], "GET",
                                "/v1/snapshot?profile=" + urllib.parse.quote(profile))
        snapshot = result["snapshot"]
        if snapshot.get("status", {}).get("node_id") != resolved_id:
            raise ClusterError("远端节点身份与档案不一致")
        cluster.record_snapshot(snapshot)
        return snapshot
    except ClusterError:
        with cluster.db.connection:
            cluster.db.connection.execute(
                "UPDATE nodes SET state='unreachable',last_failure=?,updated_at=? WHERE id=?",
                (utc_now(), utc_now(), resolved_id),
            )
        raise


def broadcast_federation_events(cluster: Cluster) -> dict[str, Any]:
    """Distribute events through one bounded 1→10→100 fan-out pass."""
    node_ids = [str(row["id"]) for row in cluster.trusted_federation_nodes()]
    roots = node_ids[:FEDERATION_FANOUT]
    remainder = node_ids[FEDERATION_FANOUT:FEDERATION_FANOUT * (FEDERATION_FANOUT + 1)]
    overflow = node_ids[FEDERATION_FANOUT * (FEDERATION_FANOUT + 1):]
    delivered, failures = parallel_federation_sync(
        cluster, roots, attempts=1, coordinate_failures=False,
    )
    successful_roots = [node_id for node_id in roots if node_id in delivered]
    assignments = {root: [] for root in successful_roots}
    unassigned: list[str] = []
    for index, node_id in enumerate(remainder):
        if successful_roots and index < len(successful_roots) * FEDERATION_FANOUT:
            assignments[successful_roots[index % len(successful_roots)]].append(node_id)
        else:
            unassigned.append(node_id)
    batch_id = uuid.uuid4().hex
    deadline = utc_now() + FEDERATION_FANOUT_TTL
    relay_roots = [node_id for node_id in successful_roots if assignments[node_id]]
    relay_results, relay_failures = parallel_federation_action(
        cluster, relay_roots, "federation.relay",
        lambda relay_id: {"batch_id": batch_id, "deadline": deadline,
                          "node_ids": assignments[relay_id]}, timeout=45,
    )
    relay_child_failures: list[str] = []
    for relay_id, wrapper in relay_results.items():
        payload = _action_result_payload(wrapper)
        for node_id in payload.get("delivered", []):
            delivered[str(node_id)] = {"relay": relay_id}
        relay_child_failures.extend(str(node_id) for node_id in payload.get("failures", {}))
    relay_fallback = [node_id for relay_id in relay_failures
                      for node_id in assignments.get(relay_id, [])]
    fallback = list(dict.fromkeys(unassigned + relay_fallback + relay_child_failures + overflow))
    if fallback:
        overflow_delivered, overflow_failures = parallel_federation_sync(
            cluster, fallback, attempts=1, coordinate_failures=False,
        )
        delivered.update(overflow_delivered)
        failures.update(overflow_failures)
    return {"batch_id": batch_id, "delivered": delivered, "failures": failures,
            "relay_failures": relay_failures}


def reconcile_federation_endpoint(cluster: Cluster, *,
                                  detection: dict[str, Any] | None = None) -> dict[str, Any]:
    config = cluster.load_config()
    current = str(config.get("public_host", ""))
    observed = detection if detection is not None else detect_public_hosts()
    checked_at = int(observed.get("checked_at", utc_now()))
    cluster.db.set_setting("federation.endpoint.last_checked", str(checked_at))
    actual = str(observed.get("ip", "")) if observed.get("confirmed") else ""
    if actual:
        cluster.db.set_setting("federation.endpoint.actual", actual)
    if not observed.get("confirmed"):
        cluster.db.set_setting("federation.endpoint.actual", "")
        cluster.db.audit("federation.endpoint.unconfirmed", str(config.get("node_id", "")),
                         json_dumps(observed.get("errors", {}))[-500:])
        return {"changed": False, "confirmed": False, "detection": observed,
                "endpoint": cluster.endpoint_status(actual)}
    with FileLock(cluster.lock_path, timeout=5):
        detected_hosts = observed.get("ips") if isinstance(observed.get("ips"), list) else [actual]
        local = cluster.reconcile_public_endpoint(actual, detected_hosts)
    if not local["changed"]:
        return {"changed": False, "confirmed": True, "detection": observed,
                "endpoint": cluster.endpoint_status(actual)}
    try:
        propagation = broadcast_federation_events(cluster)
    except (ClusterError, OSError, sqlite3.Error) as exc:
        propagation = {"batch_id": "", "delivered": {},
                       "failures": {"broadcast": str(exc)[-1000:]}}
    try:
        publication = push_snapshot(cluster)
    except (ClusterError, OSError, sqlite3.Error) as exc:
        publication = {"peers": {}, "error": str(exc)[-1000:]}
    failures = dict(propagation.get("failures", {}))
    cluster.db.set_setting("federation.endpoint.pending", json_dumps(failures))
    cluster.db.set_setting(
        "federation.endpoint.success",
        json_dumps({str(node_id): utc_now() for node_id in propagation.get("delivered", {})}),
    )
    try:
        refreshed = len(cluster.refresh_profiles())
    except (ClusterError, OSError, sqlite3.Error) as exc:
        refreshed = 0
        cluster.db.audit("federation.endpoint.refresh-failed",
                         str(config.get("node_id", "")), str(exc)[-500:])
    return {**local, "confirmed": True, "detection": observed,
            "propagation": propagation, "publication": publication,
            "refreshed": refreshed,
            "endpoint": cluster.endpoint_status(actual)}


def push_node_identity(cluster: Cluster, node_id: str, *, propagate: bool = False,
                       publish_local: bool = False) -> dict[str, Any]:
    row = cluster.node(node_id)
    location = {key: row[key] for key in ("country_code", "country", "region", "city", "provider")}
    place = cluster.identity_place(row)
    local_id = str(cluster.load_config().get("node_id", ""))
    if str(row["id"]) == local_id:
        identity = cluster.apply_identity_transaction(int(row["server_number"]), location, place)
        cluster.record_local_snapshot()
        metadata = cluster.publish_local_node_metadata() if cluster.is_federation() and propagate else None
        propagation = broadcast_federation_events(cluster) if metadata else {}
        publication = push_snapshot(cluster) if metadata else {}
        cluster.mark_identity_synced(cluster.node(str(row["id"])))
        return {"identity": identity, "snapshot": cluster.local_snapshot(), "metadata": metadata,
                "propagation": propagation, "publication": publication}
    publish_mode: bool | str = True if propagate else ("local" if publish_local else False)
    result = send_action(cluster, row["id"], "identity.apply", {
        "server_number": int(row["server_number"]), "location": location, "place": place,
        "publish": publish_mode,
    })
    payload = result.get("result") if isinstance(result.get("result"), dict) else {}
    remote_identity = payload.get("identity") if isinstance(payload.get("identity"), dict) else {}
    if safe_label(str(remote_identity.get("place", "")), 48) != place:
        raise ClusterError("子 VPS 未应用同地区编号，请先更新该节点的 Lun 联动模块")
    snapshot = payload.get("snapshot") if isinstance(payload.get("snapshot"), dict) else None
    if snapshot:
        if cluster.is_federation() and isinstance(snapshot.get("federation_signature"), dict):
            cluster.record_federation_snapshot(snapshot)
        else:
            cluster.record_snapshot(snapshot)
    if cluster.is_federation() and propagate:
        federation_sync(cluster, str(row["id"]), attempts=2, coordinate_failures=False)
        result["propagation"] = broadcast_federation_events(cluster)
    cluster.mark_identity_synced(cluster.node(str(row["id"])))
    return result


def fetch_federation_snapshots(cluster: Cluster, node_ids: Iterable[str],
                               timeout: int = 8) -> tuple[dict[str, dict[str, Any]], dict[str, str]]:
    responses, failures = parallel_federation_action(
        cluster, node_ids, "federation.snapshot", lambda _node_id: {}, timeout=timeout
    )
    snapshots: dict[str, dict[str, Any]] = {}
    for node_id, wrapper in responses.items():
        payload = _action_result_payload(wrapper)
        snapshot = payload.get("snapshot") if isinstance(payload.get("snapshot"), dict) else None
        if not snapshot:
            failures[node_id] = "成员未返回签名订阅快照"
            continue
        try:
            cluster.record_federation_snapshot(snapshot)
            snapshots[node_id] = snapshot
        except ClusterError as exc:
            failures[node_id] = str(exc)
    return snapshots, failures


def deliver_federation_snapshots(cluster: Cluster,
                                 deliveries: Iterable[tuple[str, dict[str, Any]]], *,
                                 timeout: int = 5) -> tuple[list[str], dict[str, str]]:
    tasks: list[tuple[str, str, int, dict[str, Any], str]] = []
    for target_id, snapshot in deliveries:
        target = cluster.node(target_id)
        source = str(snapshot.get("status", {}).get("node_id", ""))
        tasks.append((str(target["id"]), str(target["endpoint_host"]),
                      int(target["endpoint_port"]), snapshot, source))
    delivered: list[str] = []
    failures: dict[str, str] = {}
    if not tasks:
        return delivered, failures
    relay = {"batch_id": uuid.uuid4().hex, "deadline": utc_now() + FEDERATION_FANOUT_TTL}

    def deliver_one(task: tuple[str, str, int, dict[str, Any], str]) -> str:
        target_id, host, port, snapshot, source = task
        try:
            mutual_request(
                cluster, host, port, "POST", "/v1/federation/snapshot",
                {"snapshot": snapshot, "relay": relay}, timeout=timeout,
            )
            return f"{target_id}:{source}"
        finally:
            cluster.db.close()

    with concurrent.futures.ThreadPoolExecutor(
            max_workers=min(FEDERATION_FANOUT, len(tasks))) as executor:
        futures = {executor.submit(deliver_one, task): task for task in tasks}
        for future in concurrent.futures.as_completed(futures):
            target_id, _host, _port, _snapshot, source = futures[future]
            key = f"{target_id}:{source}"
            try:
                delivered.append(future.result())
            except Exception as exc:
                failures[key] = str(exc)[-1000:]
    return delivered, failures


def push_snapshot(cluster: Cluster, profile: str = "legacy") -> dict[str, Any]:
    config = cluster.load_config()
    if cluster.is_federation():
        cluster.record_local_snapshot(profile)
        snapshot = cluster.federation_snapshot(profile)
        delivered: dict[str, str] = {}
        peers = [(str(row["id"]), str(row["endpoint_host"]), int(row["endpoint_port"]))
                 for row in cluster.trusted_federation_nodes()]

        def publish_one(peer: tuple[str, str, int]) -> tuple[str, str]:
            node_id, host, port = peer
            try:
                mutual_request(
                    cluster, host, port, "POST", "/v1/federation/snapshot",
                    {"snapshot": snapshot}, timeout=15,
                )
                return node_id, "ok"
            except ClusterError as exc:
                return node_id, f"failed: {exc}"
            finally:
                cluster.db.close()

        if peers:
            with concurrent.futures.ThreadPoolExecutor(
                    max_workers=min(FEDERATION_FANOUT, len(peers))) as executor:
                for node_id, status in executor.map(publish_one, peers):
                    delivered[node_id] = status
                    if status != "ok":
                        cluster.record_transport_failure(node_id)
        return {"snapshot": snapshot, "peers": delivered}
    if config.get("role") != "child" or not config.get("paired"):
        raise ClusterError("当前服务器不是已配对子 VPS")
    return mutual_request(
        cluster, config["controller_host"], int(config["controller_port"]), "POST",
        "/v1/events/snapshot", {"snapshot": cluster.local_snapshot(profile)},
    )


def send_role_transfer(cluster: Cluster, target_id: str, data: bytes) -> str:
    target = cluster.node(target_id)
    config = cluster.load_config()
    transfer_id = uuid.uuid4().hex
    digest = hashlib.sha256(data).hexdigest()
    total = (len(data) + ROLE_TRANSFER_CHUNK - 1) // ROLE_TRANSFER_CHUNK
    try:
        for index in range(total):
            chunk = data[index * ROLE_TRANSFER_CHUNK:(index + 1) * ROLE_TRANSFER_CHUNK]
            send_action(cluster, str(target["id"]), "role.stage", {
                "transfer_id": transfer_id, "sha256": digest, "source_id": config["node_id"],
                "target_id": str(target["id"]), "index": index, "total": total, "size": len(data),
                "data": base64.b64encode(chunk).decode(),
            })
    except Exception:
        with contextlib.suppress(Exception):
            send_action(cluster, str(target["id"]), "role.discard", {"transfer_id": transfer_id})
        raise
    return transfer_id


def wait_for_remote_role(cluster: Cluster, node: sqlite3.Row, role: str, timeout: int = 45) -> dict[str, Any]:
    deadline = time.monotonic() + timeout
    last_error = ""
    while time.monotonic() < deadline:
        try:
            result = mutual_request(
                cluster, node["endpoint_host"], int(node["endpoint_port"]), "GET", "/v1/status", timeout=8
            )
            status = result.get("status") if isinstance(result.get("status"), dict) else {}
            if status.get("node_id") == node["id"] and status.get("role") == role:
                return status
            last_error = f"远端角色仍为 {status.get('role', 'unknown')}"
        except ClusterError as exc:
            last_error = str(exc)
        time.sleep(1)
    raise ClusterError(f"等待新主 VPS 启动超时：{last_error or '无响应'}")


def demote_local_master(cluster: Cluster, target_id: str) -> dict[str, Any]:
    config = cluster.load_config()
    if config.get("role") != "master":
        raise ClusterError("当前服务器已经不是主 VPS")
    target = cluster.node(target_id)
    if target["role"] != "child":
        raise ClusterError("目标服务器不是子 VPS")
    local = cluster.node(str(config.get("node_id", "")))
    recovery = cluster.create_role_recovery("before-demote")
    try:
        with cluster.db.connection:
            cluster.db.connection.execute("UPDATE nodes SET role='child' WHERE id=?", (local["id"],))
            cluster.db.connection.execute("UPDATE nodes SET role='master' WHERE id=?", (target["id"],))
        for key in (
            "role_switch_pending", "role_switch_source_id", "role_switch_transfer_id",
            "role_switch_recovery", "previous_master_id", "pending_controller",
        ):
            config.pop(key, None)
        config.update({
            "role": "child", "paired": True, "controller_id": str(target["id"]),
            "controller_host": str(target["endpoint_host"]),
            "controller_port": int(target["endpoint_port"]),
            "server_number": int(local["server_number"]),
        })
        cluster.save_config(config)
        location = {key: local[key] for key in ("country_code", "country", "region", "city", "provider")}
        cluster.apply_local_identity(
            int(local["server_number"]), location, cluster.identity_place(local)
        )
        cluster.db.audit("role.demote", str(local["id"]), f"controller={short_id(str(target['id']))}")
        (cluster.pki / "cluster-ca.key").unlink(missing_ok=True)
        cluster.secure_files()
        return {"role": "child", "controller_id": str(target["id"]), "recovery": str(recovery)}
    except Exception:
        with contextlib.suppress(Exception):
            cluster.restore_role_recovery(recovery)
        raise


def switch_master(cluster: Cluster, target_id: str) -> dict[str, Any]:
    config = cluster.load_config()
    if config.get("role") != "master":
        raise ClusterError("只有当前主 VPS 可以发起角色互换")
    target = cluster.node(target_id)
    if target["role"] != "child":
        raise ClusterError("目标必须是当前集群中的子 VPS")
    target_id = str(target["id"])
    sync_node(cluster, target_id)
    target = cluster.node(target_id)
    controller = {"id": target_id, "host": str(target["endpoint_host"]), "port": int(target["endpoint_port"])}
    others = [
        str(row["id"]) for row in cluster.db.connection.execute(
            "SELECT id FROM nodes WHERE role='child' AND id<>? ORDER BY server_number,id", (target_id,)
        )
    ]
    for node_id in others:
        sync_node(cluster, node_id)
    outdated: list[str] = []
    for node_id in [target_id, *others]:
        row = cluster.node(node_id)
        if int(row["api_version"] or 0) < 2:
            outdated.append(f"{int(row['server_number']):02d}")
    if outdated:
        raise ClusterError(
            "以下服务器的联动程序不支持安全角色互换，请先分别更新：" + ", ".join(outdated)
        )
    prepared: list[str] = []
    promoted = False
    committed = False
    transfer_id = ""
    try:
        transfer = cluster.build_role_transfer(target_id)
        transfer_id = send_role_transfer(cluster, target_id, transfer)
        for node_id in others:
            send_action(cluster, node_id, "controller.prepare", {"controller": controller})
            prepared.append(node_id)
        promoted = True
        send_action(cluster, target_id, "role.promote", {"transfer_id": transfer_id})
        time.sleep(5)
        wait_for_remote_role(cluster, target, "master")
        if others:
            send_action(cluster, target_id, "role.children-commit", {"node_ids": others})
            committed = True
        demotion = demote_local_master(cluster, target_id)
    except Exception as exc:
        rollback_errors: dict[str, str] = {}
        if promoted and committed:
            try:
                send_action(cluster, target_id, "role.children-revert", {"node_ids": others})
            except Exception as rollback_exc:
                rollback_errors["children"] = str(rollback_exc)
        for node_id in prepared:
            try:
                send_action(cluster, node_id, "controller.abort", {})
            except Exception as rollback_exc:
                rollback_errors[f"abort:{short_id(node_id)}"] = str(rollback_exc)
        if promoted:
            try:
                send_action(cluster, target_id, "role.rollback", {})
            except Exception as rollback_exc:
                rollback_errors["target"] = str(rollback_exc)
        if transfer_id:
            with contextlib.suppress(Exception):
                send_action(cluster, target_id, "role.discard", {"transfer_id": transfer_id})
        detail = {"error": str(exc), "rollback_errors": rollback_errors}
        raise ClusterError("主 VPS 角色互换失败：" + json_dumps(detail)) from exc
    finalize_warning = ""
    try:
        send_action(cluster, target_id, "role.finalize", {})
    except ClusterError as exc:
        finalize_warning = str(exc)
    return {
        "old_master": config["node_id"], "new_master": target_id,
        "new_master_host": str(target["endpoint_host"]),
        "new_master_port": int(target["endpoint_port"]), "server_number": int(target["server_number"]),
        "demotion_recovery": demotion["recovery"], "finalize_warning": finalize_warning,
    }


def validate_lun_environment(payload: dict[str, Any]) -> dict[str, str]:
    unknown = set(payload) - LUN_ENV_FIELDS
    if unknown:
        raise ClusterError("不支持的 Lun 配置字段：" + ", ".join(sorted(unknown)))
    result: dict[str, str] = {}
    for key, raw in payload.items():
        if raw is None:
            continue
        value = str(raw)
        if "\x00" in value or len(value) > 8192:
            raise ClusterError(f"字段 {key} 内容无效")
        if key in PORT_ENV_FIELDS and value:
            if not value.isdigit() or not valid_port(int(value)):
                raise ClusterError(f"字段 {key} 必须是有效端口")
        if key == "vpsmode" and value not in {"normal", "nat"}:
            raise ClusterError("vpsmode 只支持 normal 或 nat")
        if key == "ptmap" and value:
            for pair in value.split():
                if not re.fullmatch(r"[0-9]{1,5}-[0-9]{1,5}", pair):
                    raise ClusterError("ptmap 必须使用 公网端口-内网端口")
                if not all(valid_port(int(item)) for item in pair.split("-", 1)):
                    raise ClusterError("ptmap 包含无效端口")
        if key == "uuid" and value:
            with contextlib.suppress(ValueError):
                value = str(uuid.UUID(value))
            if not re.fullmatch(r"[0-9a-f-]{36}", value):
                raise ClusterError("UUID 格式无效")
        if key in {"domain", "cdnym", "agn"} and value and value not in {"del", "none", "off"}:
            normalize_host(value)
        result[key] = value
    return result


def execute_action(cluster: Cluster, request: dict[str, Any], peer_id: str = "local") -> dict[str, Any]:
    action = str(request.get("action", ""))
    request_id = str(request.get("request_id", ""))
    target = cluster.load_config().get("node_id", "")
    if action not in ACTION_NAMES:
        raise ClusterError("远程操作不在允许列表")
    if not re.fullmatch(r"[0-9a-f-]{16,64}", request_id):
        raise ClusterError("request_id 无效")
    existing = cluster.db.connection.execute("SELECT * FROM jobs WHERE request_id=?", (request_id,)).fetchone()
    if existing:
        return {"request_id": request_id, "status": existing["status"], "detail": existing["detail"], "replayed": True}
    payload = request.get("payload") if isinstance(request.get("payload"), dict) else {}
    now = utc_now()
    with cluster.db.connection:
        cluster.db.connection.execute(
            "INSERT INTO jobs(request_id,node_id,action,status,created_at,updated_at) VALUES(?,?,?,?,?,?)",
            (request_id, target, action, "running", now, now),
        )
    try:
        with FileLock(cluster.lock_path, timeout=5):
            result = _execute_action_locked(cluster, action, payload, request, peer_id)
        status = "success"
        detail = json_dumps(result)[:2000]
    except Exception as exc:
        status = "failed"
        detail = str(exc)[:2000]
        with cluster.db.connection:
            cluster.db.connection.execute(
                "UPDATE jobs SET status=?,detail=?,updated_at=? WHERE request_id=?",
                (status, detail, utc_now(), request_id),
            )
        cluster.db.audit("action.failed", action, f"peer={short_id(peer_id)} {detail}")
        if isinstance(exc, ClusterError):
            raise
        raise ClusterError(detail) from exc
    with cluster.db.connection:
        cluster.db.connection.execute(
            "UPDATE jobs SET status=?,detail=?,updated_at=? WHERE request_id=?",
            (status, detail, utc_now(), request_id),
        )
    cluster.db.audit("action.success", action, f"peer={short_id(peer_id)}")
    return {"request_id": request_id, "status": status, "result": result}


def validate_script_install_payload(payload: dict[str, Any]) -> bytes:
    encoded = str(payload.get("content", ""))
    expected = str(payload.get("sha256", ""))
    try:
        content = b64decode(encoded)
    except (ValueError, binascii.Error) as exc:
        raise ClusterError("脚本内容编码无效") from exc
    if hashlib.sha256(content).hexdigest() != expected:
        raise ClusterError("脚本 SHA-256 不匹配")
    if len(content) > 2 * 1024 * 1024 or not content.startswith(b"#!/"):
        raise ClusterError("脚本内容无效")
    return content


def validate_agent_install_payload(payload: dict[str, Any]) -> tuple[bytes, str]:
    encoded = str(payload.get("content", ""))
    expected = str(payload.get("sha256", ""))
    try:
        content = b64decode(encoded)
        source = content.decode("utf-8")
    except (ValueError, UnicodeDecodeError, binascii.Error) as exc:
        raise ClusterError("联动程序内容编码无效") from exc
    if hashlib.sha256(content).hexdigest() != expected:
        raise ClusterError("联动程序 SHA-256 不匹配")
    if len(content) > 2 * 1024 * 1024 or not content.startswith(b"#!/usr/bin/env python3"):
        raise ClusterError("联动程序内容无效")
    try:
        compile(source, "lun_cluster.py", "exec")
    except SyntaxError as exc:
        raise ClusterError("新联动程序语法检查失败") from exc
    return content, source


def install_script_payload(cluster: Cluster, script: Path, payload: dict[str, Any]) -> dict[str, Any]:
    content = validate_script_install_payload(payload)
    script.parent.mkdir(parents=True, exist_ok=True)
    with tempfile.NamedTemporaryFile(dir=str(script.parent), delete=False) as handle:
        handle.write(content)
        temporary = Path(handle.name)
    try:
        if cluster._run(["bash", "-n", str(temporary)], check=False).returncode:
            raise ClusterError("新 Lun 脚本语法检查失败")
        os.chmod(temporary, 0o755)
        backup = script.with_name(script.name + ".cluster-backup")
        if script.exists():
            shutil.copy2(script, backup)
        os.replace(temporary, script)
    finally:
        temporary.unlink(missing_ok=True)
    return {"sha256": hashlib.sha256(content).hexdigest(), "path": str(script)}


def install_agent_payload(payload: dict[str, Any]) -> dict[str, Any]:
    content, _ = validate_agent_install_payload(payload)
    destination = Path(__file__).resolve()
    with tempfile.NamedTemporaryFile(dir=str(destination.parent), delete=False) as handle:
        handle.write(content)
        temporary = Path(handle.name)
    try:
        os.chmod(temporary, 0o755)
        backup = destination.with_name(destination.name + ".cluster-backup")
        if destination.exists():
            shutil.copy2(destination, backup)
        os.replace(temporary, destination)
    finally:
        temporary.unlink(missing_ok=True)
    return {
        "sha256": hashlib.sha256(content).hexdigest(), "path": str(destination),
        "restart_required": True,
    }


def _execute_action_locked(cluster: Cluster, action: str, payload: dict[str, Any], request: dict[str, Any],
                           peer_id: str = "local") -> dict[str, Any]:
    script = Path(os.environ.get("LUN_SCRIPT", "/usr/bin/lun"))
    if action in {"cdn.pool.preview", "cdn.pool.apply"}:
        if set(payload) != {"mode", "cfip"}:
            raise ClusterError("CDN 优选池操作只接受 mode 与 cfip")
        mode, cfip = str(payload.get("mode", "")), str(payload.get("cfip", ""))
        if action == "cdn.pool.preview":
            return cluster.preview_cdn_pool(mode, cfip)
        return cluster.apply_cdn_pool(mode, cfip, script)
    if action == "role.stage":
        return cluster.stage_role_transfer(payload, peer_id)
    if action == "role.discard":
        return cluster.discard_role_transfer(str(payload.get("transfer_id", "")), peer_id)
    if action == "role.promote":
        return cluster.promote_from_role_transfer(str(payload.get("transfer_id", "")), peer_id)
    if action == "role.rollback":
        return cluster.rollback_role_promotion(peer_id)
    if action == "role.finalize":
        return cluster.finalize_role_promotion(peer_id)
    if action in {"controller.prepare", "controller.reassign"}:
        config = cluster.load_config()
        if config.get("role") != "child" or config.get("controller_id") != peer_id:
            raise ClusterError("只有当前主 VPS 可以修改子 VPS 的控制器")
        controller = payload.get("controller") if isinstance(payload.get("controller"), dict) else {}
        controller_id = str(controller.get("id", ""))
        if not re.fullmatch(r"[0-9a-f]{32}", controller_id) or controller_id == config.get("node_id"):
            raise ClusterError("新主 VPS 身份无效")
        host = normalize_host(str(controller.get("host", "")))
        try:
            port = int(controller.get("port", 0))
        except (TypeError, ValueError) as exc:
            raise ClusterError("新主 VPS 通信端口无效") from exc
        if not valid_port(port):
            raise ClusterError("新主 VPS 通信端口无效")
        if action == "controller.prepare":
            config["pending_controller"] = {
                "id": controller_id, "host": host, "port": port,
                "expires_at": utc_now() + ROLE_TRANSFER_TTL,
            }
            cluster.save_config(config)
            cluster.db.audit("controller.prepare", config.get("node_id", ""), short_id(controller_id))
            return {"pending_controller": controller_id, "expires_at": config["pending_controller"]["expires_at"]}
        config.update({"controller_id": controller_id, "controller_host": host, "controller_port": port})
        config.pop("pending_controller", None)
        cluster.save_config(config)
        cluster.db.audit("controller.reassign", config.get("node_id", ""), short_id(controller_id))
        return {"controller_id": controller_id}
    if action == "controller.abort":
        config = cluster.load_config()
        if config.get("role") != "child" or config.get("controller_id") != peer_id:
            raise ClusterError("只有当前主 VPS 可以取消控制器切换")
        config.pop("pending_controller", None)
        cluster.save_config(config)
        cluster.db.audit("controller.abort", config.get("node_id", ""), short_id(peer_id))
        return {"pending": False}
    if action == "controller.commit":
        config = cluster.load_config()
        pending = config.get("pending_controller") if isinstance(config.get("pending_controller"), dict) else {}
        if (
            config.get("role") != "child" or pending.get("id") != peer_id
            or int(pending.get("expires_at", 0)) < utc_now()
        ):
            raise ClusterError("新主 VPS 的临时授权无效或已过期")
        config.update({
            "controller_id": peer_id, "controller_host": normalize_host(str(pending.get("host", ""))),
            "controller_port": int(pending.get("port", 0)),
        })
        config.pop("pending_controller", None)
        cluster.save_config(config)
        cluster.db.audit("controller.commit", config.get("node_id", ""), short_id(peer_id))
        return {"controller_id": peer_id}
    if action in {"role.children-commit", "role.children-revert"}:
        config = cluster.load_config()
        if (
            config.get("role") != "master" or not config.get("role_switch_pending")
            or config.get("role_switch_source_id") != peer_id
        ):
            raise ClusterError("当前不处于该原主 VPS 发起的角色切换中")
        raw_ids = payload.get("node_ids") if isinstance(payload.get("node_ids"), list) else []
        node_ids: list[str] = []
        for value in raw_ids:
            row = cluster.node(str(value))
            if row["role"] != "child" or row["id"] in {peer_id, config.get("node_id")}:
                raise ClusterError("角色切换子机列表包含无效节点")
            if row["id"] not in node_ids:
                node_ids.append(str(row["id"]))
        old = cluster.node(peer_id)
        old_controller = {
            "id": peer_id, "host": str(old["endpoint_host"]), "port": int(old["endpoint_port"]),
        }
        if action == "role.children-revert":
            failures: dict[str, str] = {}
            for node_id in node_ids:
                try:
                    send_action(cluster, node_id, "controller.reassign", {"controller": old_controller})
                except ClusterError as exc:
                    failures[node_id] = str(exc)
            if failures:
                raise ClusterError("部分子 VPS 未能恢复原主控：" + json_dumps(failures))
            return {"reverted": node_ids}
        for node_id in node_ids:
            node = cluster.node(node_id)
            result = mutual_request(
                cluster, node["endpoint_host"], node["endpoint_port"], "GET", "/v1/status", timeout=20
            )
            if result.get("status", {}).get("node_id") != node_id:
                raise ClusterError(f"子 VPS {short_id(node_id)} 临时授权验证失败")
        committed: list[str] = []
        try:
            for node_id in node_ids:
                send_action(cluster, node_id, "controller.commit", {})
                committed.append(node_id)
        except ClusterError as exc:
            rollback_failures: dict[str, str] = {}
            for node_id in committed:
                try:
                    send_action(cluster, node_id, "controller.reassign", {"controller": old_controller})
                except ClusterError as rollback_exc:
                    rollback_failures[node_id] = str(rollback_exc)
            detail = {"error": str(exc), "rollback_failures": rollback_failures}
            raise ClusterError("子 VPS 控制器提交失败：" + json_dumps(detail)) from exc
        return {"committed": committed}
    if action == "identity.apply":
        try:
            server_number = int(payload.get("server_number", 0))
        except (TypeError, ValueError) as exc:
            raise ClusterError("服务器编号无效") from exc
        location = payload.get("location") if isinstance(payload.get("location"), dict) else None
        place = safe_label(str(payload.get("place", "")), 48)
        if server_number < 1 or location is None:
            raise ClusterError("服务器身份数据无效")
        identity = cluster.apply_identity_transaction(server_number, location, place)
        publish_mode = payload.get("publish", False)
        metadata = cluster.publish_local_node_metadata() \
            if cluster.is_federation() and bool(publish_mode) else None
        publication = push_snapshot(cluster) if metadata and publish_mode is True else {}
        snapshot = cluster.federation_snapshot() if cluster.is_federation() else cluster.local_snapshot()
        return {"identity": identity, "snapshot": snapshot, "metadata": metadata,
                "publication": publication}
    if action == "status.refresh":
        return cluster.local_status()
    if action == "subscription.refresh":
        return cluster.local_snapshot(str(payload.get("profile", "legacy")))
    if action == "snapshot.create":
        return {"path": str(cluster.create_snapshot(str(payload.get("label", "remote"))))}
    if action == "snapshot.restore":
        name = Path(str(payload.get("name", ""))).name
        source = cluster.backups / name
        if not source.exists():
            raise ClusterError("快照不存在")
        restored = cluster.restore_snapshot(source)
        result = cluster._run(["bash", str(script), "res"], timeout=300, check=False)
        if result.returncode:
            raise ClusterError((result.stderr or result.stdout or "快照恢复后服务启动失败")[-2000:])
        restored["output"] = result.stdout[-2000:]
        return restored
    if action == "user.sync":
        origin = str(payload.get("origin", ""))
        bundle = payload.get("bundle")
        if not re.fullmatch(r"[0-9a-f]{32}", origin) or not isinstance(bundle, dict):
            raise ClusterError("主 VPS 用户同步数据无效")
        if origin != cluster.load_config().get("cluster_id"):
            raise ClusterError("主 VPS 集群身份不匹配")
        prepared = cluster._run(["bash", str(script), "cluster-prepare-multiuser"], timeout=900, check=False)
        if prepared.returncode:
            raise ClusterError((prepared.stderr or prepared.stdout or "子 VPS 多用户环境准备失败")[-2000:])
        agent = cluster.root / "modules" / "multiuser" / "lun-agent"
        if not agent.exists():
            raise ClusterError("子 VPS 缺少多用户程序")
        with tempfile.NamedTemporaryFile("w", encoding="utf-8", dir=str(cluster.module), delete=False) as handle:
            json.dump(bundle, handle, ensure_ascii=False)
            temporary = Path(handle.name)
        os.chmod(temporary, 0o600)
        try:
            imported = cluster._run(
                [str(agent), "--root", str(cluster.root), "cluster-import", "--path", str(temporary),
                 "--origin", origin], timeout=120, check=False,
            )
        finally:
            temporary.unlink(missing_ok=True)
        if imported.returncode:
            raise ClusterError((imported.stderr or imported.stdout or "主 VPS 用户导入失败")[-2000:])
        applied = cluster._run([str(agent), "--root", str(cluster.root), "apply"], timeout=300, check=False)
        if applied.returncode:
            raise ClusterError((applied.stderr or applied.stdout or "子 VPS 多用户配置应用失败")[-2000:])
        return {"import": imported.stdout[-2000:], "apply": applied.stdout[-2000:]}
    if action in {"lun.factory-reset", "lun.uninstall"}:
        confirm = str(payload.get("confirm", ""))
        if confirm != short_id(cluster.load_config().get("node_id", "")):
            raise ClusterError("危险操作校验码不匹配")
        if action == "lun.factory-reset":
            multiuser = cluster.root / "modules" / "multiuser" / "config.json"
            if multiuser.exists():
                with contextlib.suppress(OSError, json.JSONDecodeError):
                    if json.loads(multiuser.read_text(encoding="utf-8")).get("enabled"):
                        raise ClusterError("子 VPS 多用户模块仍在启用，为避免凭据失配已拒绝清空")
        snapshot = cluster.create_snapshot("before-destructive-action")
        recovery = Path.home() / f"lun-cluster-recovery-{utc_now()}.tar.gz"
        shutil.copy2(snapshot, recovery)
        os.chmod(recovery, 0o600)
        command = "cluster-factory-reset" if action.endswith("factory-reset") else "cluster-uninstall"
        environment = os.environ.copy()
        environment["LUN_CLUSTER_DESTRUCTIVE"] = "yes"
        subprocess.Popen(
            ["bash", str(script), command], env=environment, stdin=subprocess.DEVNULL,
            stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, start_new_session=True,
        )
        return {"snapshot": str(recovery), "scheduled": True}
    if action == "cluster.update-all":
        if cluster.load_config().get("role") != "master" and not cluster.is_federation():
            raise ClusterError("只有主 VPS 可以向全部服务器分发更新")
        return distribute_cluster_update(cluster, payload, source_peer=peer_id, install_local=True)
    if action == "federation.catchup":
        if not cluster.is_federation():
            raise ClusterError("当前不是联邦模式")
        if payload:
            raise ClusterError("联邦订阅补齐不接受额外参数")
        return {"catchup": cluster.subscription_catchup(), "publication": push_snapshot(cluster)}
    if action == "federation.relay":
        if not cluster.is_federation():
            raise ClusterError("当前不是联邦模式")
        return federation_relay(cluster, payload, peer_id)
    if action == "federation.snapshot":
        if not cluster.is_federation() or payload:
            raise ClusterError("联邦快照读取仅适用于无参数联邦操作")
        return {"snapshot": cluster.federation_snapshot()}
    if action == "script.install":
        return install_script_payload(cluster, script, payload)
    if action == "agent.install":
        return install_agent_payload(payload)
    if not script.exists():
        raise ClusterError("没有找到可执行的 Lun 主脚本")
    if action == "protocol.apply":
        environment = os.environ.copy()
        environment.update(validate_lun_environment(payload))
        if not any(key in environment for key in PORT_ENV_FIELDS):
            raise ClusterError("协议重建至少需要一个协议端口字段")
        result = cluster._run(["bash", str(script), "rep"], timeout=900, env=environment, check=False)
    elif action == "service.restart":
        result = cluster._run(["bash", str(script), "res"], timeout=300, check=False)
    elif action == "service.control":
        component = str(payload.get("component", ""))
        operation = str(payload.get("operation", ""))
        components = {"xray", "singbox", "argo", "subscription", "multiuser", "visit", "cluster"}
        if component not in components or operation not in {"status", "start", "stop", "restart"}:
            raise ClusterError("服务控制参数无效")
        if component == "cluster":
            if operation == "status":
                return {"component": component, "operation": operation, "running": True}
            if operation != "restart":
                raise ClusterError("联动服务仅允许远程查看或重启，避免主 VPS 失去控制通道")
            return {"component": component, "operation": operation, "restart_required": True}
        result = cluster._run(
            ["bash", str(script), "cluster-service-control", component, operation],
            timeout=180, check=False,
        )
    elif action == "core.update":
        core = payload.get("core")
        if core not in {"xray", "singbox"}:
            raise ClusterError("core 只支持 xray 或 singbox")
        result = cluster._run(["bash", str(script), "upx" if core == "xray" else "ups"], timeout=900, check=False)
    elif action == "firewall.apply":
        result = cluster._run(["bash", str(script), "cluster-firewall"], timeout=120, check=False)
    else:
        raise ClusterError("该操作尚未映射到 Lun 固定入口")
    output = ((result.stdout or "") + (result.stderr or ""))[-4000:]
    if result.returncode:
        raise ClusterError(output or "Lun 操作失败")
    with contextlib.suppress(ClusterError):
        push_snapshot(cluster)
    return {"returncode": result.returncode, "output": output}


def send_action(cluster: Cluster, node_id: str, action: str, payload: dict[str, Any],
                timeout: int = 900, *, coordinate_failures: bool = True) -> dict[str, Any]:
    node = cluster.node(node_id)
    if cluster.is_federation():
        trusted = cluster.db.connection.execute("SELECT revoked_at FROM federation_keys WHERE node_id=?", (node["id"],)).fetchone()
        if not trusted or int(trusted["revoked_at"]):
            raise ClusterError("旧迁移候选或已撤销节点不能执行联邦远控")
    if action in {"lun.factory-reset", "lun.uninstall"} and str(payload.get("confirm", "")) == node_id:
        payload = {**payload, "confirm": short_id(node["id"])}
    request = {"schema_version": API_VERSION, "request_id": uuid.uuid4().hex, "action": action, "payload": payload}
    last_error: FederationTransportError | None = None
    attempts = 3 if cluster.is_federation() and coordinate_failures else 1
    for attempt in range(attempts):
        try:
            result = mutual_request(
                cluster, node["endpoint_host"], node["endpoint_port"],
                "POST", "/v1/action", request, timeout=timeout,
            )
            if cluster.is_federation():
                cluster.record_transport_success(str(node["id"]))
            return result["result"]
        except FederationTransportError as exc:
            last_error = exc
    if cluster.is_federation() and coordinate_failures:
        failure = cluster.record_transport_failure(str(node["id"]))
        health = cluster._coordinate_after_failures(
            str(node["id"]), list(failure["failure_times"])[-3:]
        ) if failure["needs_probe"] else failure
        raise FederationTransportError(
            f"federation action failed after {attempts} idempotent attempts; health={json_dumps(health)}; error={last_error}"
        ) from last_error
    if last_error:
        raise last_error
    raise ClusterError("remote action failed")


def cdn_pool_command(cluster: Cluster, node_id: str, mode: str, cfip: str, *, apply: bool) -> dict[str, Any]:
    row = cluster.node(node_id)
    action = "cdn.pool.apply" if apply else "cdn.pool.preview"
    payload = {"mode": mode, "cfip": cfip}
    if str(row["id"]) != str(cluster.load_config().get("node_id", "")):
        return send_action(cluster, str(row["id"]), action, payload)
    request = {"schema_version": API_VERSION, "request_id": uuid.uuid4().hex,
               "action": action, "payload": payload}
    return execute_action(cluster, request)["result"]


def distribute_cluster_update(cluster: Cluster, payload: dict[str, Any], source_peer: str = "local",
                              install_local: bool = False) -> dict[str, Any]:
    config = cluster.load_config()
    if config.get("role") != "master" and not cluster.is_federation():
        raise ClusterError("只有主 VPS 可以向全部服务器分发更新")
    script_payload = payload.get("script") if isinstance(payload.get("script"), dict) else {}
    agent_payload = payload.get("agent") if isinstance(payload.get("agent"), dict) else {}
    script_content = validate_script_install_payload(script_payload)
    validate_agent_install_payload(agent_payload)
    version_match = re.search(rb"V[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+", script_content)
    lun_version = version_match.group().decode() if version_match else ""

    excluded: set[str] = set()
    raw_exclude = payload.get("exclude", "")
    exclude_values = raw_exclude if isinstance(raw_exclude, list) else re.split(r"[,\s]+", str(raw_exclude))
    for value in exclude_values:
        if not str(value).strip():
            continue
        excluded.add(str(cluster.node(str(value).strip())["id"]))
    if re.fullmatch(r"[0-9a-f]{32}", source_peer or ""):
        excluded.add(source_peer)

    results: dict[str, Any] = {}
    failures: dict[str, str] = {}
    nodes = cluster.trusted_federation_nodes() if cluster.is_federation() else [
        node for node in cluster.nodes() if node["role"] == "child"
    ]
    for node in nodes:
        node_id = str(node["id"])
        number = str(int(node["server_number"] or 0))
        if node_id in excluded:
            results[number] = {"status": "excluded" if node_id != source_peer else "source-current"}
            continue
        try:
            status = _action_result_payload(
                send_action(
                    cluster, node_id, "status.refresh", {}, timeout=12,
                    coordinate_failures=False,
                )
            )
            if status:
                cluster.upsert_node(status, role="federation" if cluster.is_federation() else "child")
            script_result = _action_result_payload(
                send_action(cluster, node_id, "script.install", script_payload, timeout=180)
            )
            agent_result = _action_result_payload(
                send_action(cluster, node_id, "agent.install", agent_payload, timeout=180)
            )
            results[number] = {
                "status": "updated", "version": lun_version,
                "script_sha256": script_result.get("sha256", ""),
                "agent_sha256": agent_result.get("sha256", ""),
            }
            with cluster.db.connection:
                cluster.db.connection.execute(
                    "UPDATE nodes SET lun_version=?,updated_at=? WHERE id=?",
                    (lun_version, utc_now(), node_id),
                )
        except Exception as exc:
            detail = str(exc)[-1000:]
            failures[number] = detail
            results[number] = {"status": "failed", "error": detail}
            with cluster.db.connection:
                cluster.db.connection.execute(
                    "UPDATE nodes SET state='unreachable',last_failure=?,updated_at=? WHERE id=?",
                    (utc_now(), utc_now(), node_id),
                )

    local_result: dict[str, Any] = {"status": "current", "version": lun_version}
    if install_local:
        script_path = Path(os.environ.get("LUN_SCRIPT", "/usr/bin/lun"))
        install_script_payload(cluster, script_path, script_payload)
        install_agent_payload(agent_payload)
        local_result = {"status": "updated", "version": lun_version}
    with contextlib.suppress(Exception):
        cluster.upsert_node(cluster.local_status(), role="federation" if cluster.is_federation() else "master")
    return {
        "complete": not failures, "version": lun_version, "local": local_result,
        "nodes": results, "failures": failures, "restart_required": install_local,
    }


def request_cluster_update(cluster: Cluster, payload: dict[str, Any]) -> dict[str, Any]:
    config = cluster.load_config()
    if config.get("role") != "child" or not config.get("paired"):
        raise ClusterError("当前服务器不是已配对子 VPS")
    request = {
        "schema_version": API_VERSION, "request_id": uuid.uuid4().hex,
        "action": "cluster.update-all", "payload": payload,
    }
    response = mutual_request(
        cluster, config["controller_host"], int(config["controller_port"]),
        "POST", "/v1/action", request, timeout=1800,
    )
    wrapper = response.get("result") if isinstance(response.get("result"), dict) else {}
    result = wrapper.get("result") if isinstance(wrapper.get("result"), dict) else {}
    if not result:
        raise ClusterError("主 VPS 未返回集群更新结果")
    return result


def _multiuser_agent_path(cluster: Cluster) -> Path:
    for candidate in (
        cluster.root / "modules" / "multiuser" / "lun-agent",
        cluster.root / "modules" / "multiuser" / "lun_agent.py",
    ):
        if candidate.exists():
            return candidate
    raise ClusterError("主 VPS 尚未安装多用户管理")


def export_master_users(cluster: Cluster, user_ids: Iterable[int] | None = None) -> dict[str, Any]:
    agent = _multiuser_agent_path(cluster)
    command = [str(agent), "--root", str(cluster.root), "--json", "cluster-export"]
    selected = list(user_ids) if user_ids is not None else None
    if selected is not None:
        command.extend(["--user-ids", ",".join(str(item) for item in selected)])
    result = cluster._run(command, timeout=60, check=False)
    if result.returncode:
        raise ClusterError((result.stderr or result.stdout or "无法导出主 VPS 用户")[-2000:])
    try:
        bundle = json.loads(result.stdout)
    except json.JSONDecodeError as exc:
        raise ClusterError("主 VPS 用户程序返回了无效数据") from exc
    if not isinstance(bundle, dict):
        raise ClusterError("主 VPS 用户数据无效")
    return bundle


def sync_federation_users(cluster: Cluster, only_node: str = "") -> dict[str, Any]:
    published = cluster.publish_local_user_events()
    local = cluster.apply_federation_users(refresh=False)
    local_id = str(cluster.load_config().get("node_id", ""))
    rows = cluster.trusted_federation_nodes()
    if only_node:
        target = str(cluster.node(only_node)["id"])
        rows = [row for row in rows if str(row["id"]) == target]
        if target != local_id and not rows:
            raise ClusterError("target is not an active trusted federation member")
    results: dict[str, Any] = {}
    failures: dict[str, str] = {}
    for node in rows:
        node_id = str(node["id"])
        try:
            results[node_id] = federation_sync(cluster, node_id)
        except (ClusterError, OSError, sqlite3.Error) as exc:
            failures[node_id] = str(exc)[-1000:]
    # Pulls may have introduced concurrent user events. Re-apply the converged view.
    local = cluster.apply_federation_users(refresh=False)
    refreshed = len(cluster.refresh_profiles())
    cluster.db.audit("federation.users.sync", only_node or "all",
                     f"events={published['events']} peers={len(results)} failures={len(failures)}")
    return {"published": published, "local": local, "nodes": results,
            "failures": failures, "refreshed": refreshed}


def sync_cluster_users(cluster: Cluster, only_node: str = "") -> dict[str, Any]:
    config = cluster.load_config()
    if cluster.is_federation():
        return sync_federation_users(cluster, only_node)
    if config.get("role") != "master":
        raise ClusterError("只有主 VPS 可以下发统一用户")
    all_bundle = export_master_users(cluster)
    users_by_id = {int(item["key"]): item for item in all_bundle.get("users", [])}
    rows = cluster.nodes()
    if only_node:
        target_id = str(cluster.node(only_node)["id"])
        rows = [row for row in rows if row["id"] == target_id]
    results: dict[str, Any] = {}
    active_profile_names: set[str] = set()
    for node in rows:
        assigned = [
            int(row["user_id"]) for row in cluster.db.connection.execute(
                "SELECT user_id FROM user_nodes WHERE node_id=? ORDER BY user_id", (node["id"],)
            )
        ]
        bundle = {"schema_version": 1, "users": [users_by_id[item] for item in assigned if item in users_by_id]}
        if node["role"] == "child":
            results[node["id"]] = send_action(
                cluster, node["id"], "user.sync",
                {"origin": config["cluster_id"], "bundle": bundle},
            )
        for user in bundle["users"]:
            assigned_nodes = [
                row["node_id"] for row in cluster.db.connection.execute(
                    "SELECT node_id FROM user_nodes WHERE user_id=? ORDER BY node_id", (int(user["key"]),)
                )
            ]
            selector = "nodes:" + ",".join(assigned_nodes)
            for device in user.get("devices", []):
                token = str(device["token"])
                profile_name = safe_label(f"用户 {user['key']} {user['name']} / {device['name']}")
                active_profile_names.add(profile_name)
                cluster.ensure_profile(profile_name, selector, token, token)
                if node["id"] in assigned_nodes:
                    if node["role"] == "master":
                        cluster.record_snapshot(cluster.local_snapshot(token), role="master")
                    else:
                        sync_node(cluster, node["id"], token)
    if not only_node:
        with cluster.db.connection:
            for profile in cluster.db.connection.execute(
                "SELECT id,name FROM profiles WHERE profile_key<>'legacy'"
            ).fetchall():
                cluster.db.connection.execute(
                    "UPDATE profiles SET enabled=?,updated_at=? WHERE id=?",
                    (int(profile["name"] in active_profile_names), utc_now(), profile["id"]),
                )
    cluster.refresh_profiles()
    cluster.db.audit("users.sync", only_node or "all", str(len(results)))
    return {"nodes": results, "users": len(users_by_id)}


def _action_result_payload(result: dict[str, Any]) -> dict[str, Any]:
    payload = result.get("result")
    return payload if isinstance(payload, dict) else {}


def batch_action(cluster: Cluster, node_ids: Iterable[str], action: str,
                 payload: dict[str, Any]) -> dict[str, Any]:
    if action in {"lun.factory-reset", "lun.uninstall", "snapshot.restore", "snapshot.create"}:
        raise ClusterError("该操作不允许批量执行")
    selected = list(dict.fromkeys(item.strip() for item in node_ids if item.strip()))
    if not selected:
        raise ClusterError("没有选择子 VPS")
    resolved = [str(cluster.node(item)["id"]) for item in selected]
    snapshots: dict[str, str] = {}
    succeeded: list[str] = []

    def apply_one(node_id: str) -> dict[str, Any]:
        local = Cluster(cluster.root)
        name = ""
        try:
            snapshot = send_action(local, node_id, "snapshot.create", {"label": f"before-batch-{action}"})
            name = Path(str(_action_result_payload(snapshot).get("path", ""))).name
            if not name:
                raise ClusterError("远程快照未返回文件名")
            result = send_action(local, node_id, action, payload)
            return {"node_id": node_id, "snapshot": name, "result": result}
        except Exception:
            if name:
                with contextlib.suppress(ClusterError):
                    send_action(local, node_id, "snapshot.restore", {"name": name})
            raise
        finally:
            local.close()

    def rollback(items: Iterable[str]) -> dict[str, str]:
        results: dict[str, str] = {}
        for node_id in items:
            name = snapshots.get(node_id, "")
            if not name:
                continue
            try:
                send_action(cluster, node_id, "snapshot.restore", {"name": name})
                results[node_id] = "restored"
            except ClusterError as exc:
                results[node_id] = f"failed: {exc}"
        return results

    # The first node is the canary.  No other node is touched until it succeeds.
    try:
        canary = apply_one(resolved[0])
        snapshots[resolved[0]] = canary["snapshot"]
        succeeded.append(resolved[0])
    except ClusterError as exc:
        raise ClusterError(f"金丝雀节点 {short_id(resolved[0])} 失败，已停止批量任务：{exc}") from exc

    failures: dict[str, str] = {}
    with concurrent.futures.ThreadPoolExecutor(max_workers=3) as executor:
        futures = {executor.submit(apply_one, node_id): node_id for node_id in resolved[1:]}
        for future in concurrent.futures.as_completed(futures):
            node_id = futures[future]
            try:
                item = future.result()
                snapshots[node_id] = item["snapshot"]
                succeeded.append(node_id)
            except Exception as exc:  # the worker converts transport errors to ClusterError
                failures[node_id] = str(exc)
    if failures:
        restored = rollback(succeeded)
        raise ClusterError(
            "批量任务失败，已尝试恢复成功节点："
            + json_dumps({"failures": failures, "rollback": restored})
        )
    return {"canary": resolved[0], "succeeded": succeeded, "snapshots": snapshots}


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(prog="lun-cluster")
    parser.add_argument("--root", default=os.path.expanduser("~/lun"))
    parser.add_argument("--json", action="store_true")
    sub = parser.add_subparsers(dest="command", required=True)

    for command in ("init-master", "init-child"):
        item = sub.add_parser(command)
        item.add_argument("--host", required=True)
        item.add_argument("--port", type=int, required=True)
        item.add_argument("--public-port", type=int)
        item.add_argument("--remark", default="")
    federation_init = sub.add_parser("federation-init")
    federation_init.add_argument("--host", required=True)
    federation_init.add_argument("--port", type=int, required=True)
    federation_init.add_argument("--public-port", type=int)
    federation_init.add_argument("--remark", default="")
    federation_init.add_argument("--migrate", action="store_true")
    sub.add_parser("federation-join-code")
    peer = sub.add_parser("add-peer")
    peer.add_argument("--uri", required=True)
    peer.add_argument("--remark", default="")
    finalize_peer = sub.add_parser("finalize-peer")
    finalize_peer.add_argument("--node-id", required=True)
    remove_peer = sub.add_parser("remove-peer")
    remove_peer.add_argument("--node-id", required=True)
    remove_peer.add_argument("--reason", default="manual")
    sub.add_parser("join-code")
    add = sub.add_parser("add-node")
    add.add_argument("--uri", required=True)
    add.add_argument("--remark", default="")
    add.add_argument("--expected-uuid", default="")
    remove = sub.add_parser("remove-node")
    remove.add_argument("--node-id", required=True)
    remove.add_argument("--confirm", required=True)
    switch = sub.add_parser("switch-master")
    switch.add_argument("--node-id", required=True)
    switch.add_argument("--confirm", required=True)
    sub.add_parser("nodes")
    sync = sub.add_parser("sync")
    sync.add_argument("--node-id", required=True)
    sync.add_argument("--profile", default="legacy")
    push = sub.add_parser("push")
    push.add_argument("--profile", default="legacy")
    aggregate = sub.add_parser("aggregate")
    aggregate.add_argument("--selector", default="all")
    aggregate.add_argument("--profile", default="legacy")
    refresh_profiles = sub.add_parser("refresh-profiles")
    refresh_profiles.add_argument("--profile", default="legacy")
    subscription_access = sub.add_parser("subscription-access")
    subscription_access.add_argument("--token", required=True)
    sub.add_parser("profiles")
    for command in ("cdn-pool-preview", "cdn-pool-sync"):
        cdn_pool = sub.add_parser(command)
        cdn_pool.add_argument("--node-id", required=True)
        cdn_pool.add_argument("--mode", choices=("merge", "replace"), required=True)
        cdn_pool.add_argument("--cfip", required=True)
    action = sub.add_parser("action")
    action.add_argument("--node-id", required=True)
    action.add_argument("--action", choices=sorted(ACTION_NAMES), required=True)
    action_payload = action.add_mutually_exclusive_group()
    action_payload.add_argument("--payload", default="{}")
    action_payload.add_argument("--payload-file")
    batch = sub.add_parser("batch-action")
    batch.add_argument("--nodes", required=True)
    batch.add_argument("--action", choices=sorted(ACTION_NAMES), required=True)
    batch_payload = batch.add_mutually_exclusive_group()
    batch_payload.add_argument("--payload", default="{}")
    batch_payload.add_argument("--payload-file")
    update_all = sub.add_parser("update-all")
    update_all.add_argument("--script-payload", required=True)
    update_all.add_argument("--agent-payload", required=True)
    update_all.add_argument("--exclude", default="")
    location = sub.add_parser("set-location")
    location.add_argument("--node-id", required=True)
    location.add_argument("--country-code", default="")
    location.add_argument("--country", default="")
    location.add_argument("--region", default="")
    location.add_argument("--city", default="")
    location.add_argument("--provider", default="")
    locate = sub.add_parser("locate")
    locate.add_argument("--node-id", required=True)
    assignment = sub.add_parser("assign-user")
    assignment.add_argument("--user-id", type=int, required=True)
    assignment.add_argument("--nodes", default="")
    sync_users = sub.add_parser("sync-users")
    sync_users.add_argument("--node-id", default="")
    backup = sub.add_parser("backup")
    backup.add_argument("--path", required=True)
    backup.add_argument("--password-file")
    restore = sub.add_parser("restore")
    restore.add_argument("--path", required=True)
    restore.add_argument("--password-file")
    federation_backup = sub.add_parser("federation-backup")
    federation_backup.add_argument("--path", required=True)
    federation_backup.add_argument("--password-file")
    identity_backup = sub.add_parser("identity-backup")
    identity_backup.add_argument("--path", required=True)
    identity_backup.add_argument("--password-file")
    federation_restore = sub.add_parser("federation-restore")
    federation_restore.add_argument("--path", required=True)
    federation_restore.add_argument("--password-file")
    identity_restore = sub.add_parser("identity-restore")
    identity_restore.add_argument("--path", required=True)
    identity_restore.add_argument("--password-file")
    sub.add_parser("endpoint-reconcile")
    sub.add_parser("revocation-check")
    sub.add_parser("status")
    sub.add_parser("serve")
    return parser


def read_password(path: str | None, prompt: str) -> str:
    if path:
        return Path(path).read_text(encoding="utf-8").rstrip("\r\n")
    value = os.environ.get("LUN_CLUSTER_BACKUP_PASSWORD")
    return value if value is not None else getpass.getpass(prompt)


def main(argv: list[str] | None = None) -> int:
    parser = build_parser()
    args = parser.parse_args(argv)
    cluster = Cluster(Path(args.root))
    result: Any = None
    try:
        if args.command == "init-master":
            result = cluster.init_master(args.host, args.port, args.public_port, args.remark)
            print("主 VPS 集群控制器已初始化。")
        elif args.command == "federation-init":
            result = cluster.federation_init(args.host, args.port, args.public_port, args.remark, args.migrate)
            print("Lun 分布式服务器集群已初始化")
        elif args.command == "federation-join-code":
            result = {"join_uri": cluster.create_join_code()}
            print("联邦加入地址：" + result["join_uri"])
        elif args.command == "add-peer":
            result = federation_add_peer(cluster, args.uri, args.remark)
            if not args.json:
                print("联邦成员已加入：" + short_id(result["node_id"]))
        elif args.command == "finalize-peer":
            result = federation_finalize_peer(
                cluster, args.node_id,
                progress=None if args.json else lambda message: print(message, flush=True),
            )
            if not args.json:
                for warning in result.get("warnings", {}).values():
                    print(terminal_color("提示：" + str(warning), "33"))
            if not result["complete"]:
                raise ClusterError("部分在线成员暂未完成收敛：" + json_dumps(result["failures"]))
            if not args.json:
                print("联邦成员自动同步完成。")
        elif args.command == "remove-peer":
            row = cluster.node(args.node_id)
            result = cluster.revoke_member(str(row["id"]), args.reason)
            result["propagation"] = broadcast_federation_events(cluster)
            result["refreshed"] = len(cluster.refresh_profiles())
            print("联邦成员已撤销：" + short_id(str(row["id"])))
        elif args.command == "init-child":
            result = cluster.init_child(args.host, args.port, args.public_port, args.remark)
            print("子 VPS 联动服务已初始化。")
            print("加入地址：" + result["join_uri"])
        elif args.command == "join-code":
            result = {"join_uri": cluster.create_join_code()}
            print("加入地址：" + result["join_uri"])
        elif args.command == "add-node":
            result = add_node(cluster, args.uri, args.remark, args.expected_uuid)
            print(f"子 VPS 已加入：{short_id(result['id'])} {result['remark']}")
        elif args.command == "remove-node":
            row = cluster.node(args.node_id)
            if args.confirm not in {args.node_id, short_id(row["id"])}:
                raise ClusterError("移除节点校验码不匹配")
            cluster.remove_node(row["id"])
            result = {"removed": row["id"]}
            print("子 VPS 已从主 VPS 移除，其旧证书已无法访问控制器。")
        elif args.command == "switch-master":
            row = cluster.node(args.node_id)
            number = f"{int(row['server_number']):02d}" if int(row["server_number"]) < 100 else str(row["server_number"])
            if args.confirm not in {"CONFIRM", f"SWITCH-{number}"}:
                raise ClusterError("确认无效，请从 Lun 集群菜单直接回车确认")
            result = switch_master(cluster, str(row["id"]))
            print(
                f"主 VPS 已切换到服务器 {number}："
                f"{result['new_master_host']}:{result['new_master_port']}"
            )
            print("服务器编号和节点名称保持不变；聚合订阅请改用新主 VPS 地址。")
            if result.get("finalize_warning"):
                print("警告：新主 VPS 订阅收尾需要手动刷新：" + result["finalize_warning"])
        elif args.command == "nodes":
            result = cluster.nodes()
            if not args.json:
                print_nodes(result)
        elif args.command == "sync":
            result = federation_sync(cluster, args.node_id) if cluster.is_federation() else sync_node(cluster, args.node_id, args.profile)
            print("节点状态和订阅快照已同步。")
        elif args.command == "push":
            result = push_snapshot(cluster, args.profile)
            print("本机状态和订阅快照已推送。")
        elif args.command == "aggregate":
            result = cluster.write_aggregate(args.selector, args.profile)
            if not args.json:
                for name, path in result.items():
                    print(f"{name}：{path}")
        elif args.command == "refresh-profiles":
            result = cluster.refresh_profiles(args.profile)
            if not args.json:
                print(f"已刷新 {len(result)} 组集群订阅。")
        elif args.command == "subscription-access":
            result = cluster.subscription_access(args.token)
            if not args.json:
                if result["debounced"]:
                    print("30 秒内已补齐过该订阅，本次已防抖跳过。")
                else:
                    print(f"订阅补齐完成：收到 {sum(result['received'].values())} 个事件，"
                          f"失败成员 {len(result['failures'])} 个，刷新 {result['refreshed']} 组订阅。")
        elif args.command == "profiles":
            result = cluster.profiles()
            if not args.json:
                for item in result:
                    print(f"{item['id']}. {item['name']}  selector={item['selector']}  token={item['token']}")
        elif args.command in {"cdn-pool-preview", "cdn-pool-sync"}:
            result = cdn_pool_command(cluster, args.node_id, args.mode, args.cfip,
                                      apply=args.command == "cdn-pool-sync")
            if not args.json:
                for label, key in (("当前", "current"), ("来源", "source"), ("结果", "result"),
                                   ("新增", "add"), ("保留", "keep"), ("移除", "remove")):
                    print(f"{label}：{' '.join(result.get(key, [])) or '-'}")
                if args.command == "cdn-pool-sync":
                    print("应用成功。" if result.get("applied") else
                          f"应用失败，已回滚：{json_dumps(result.get('rollback'))}")
            if args.command == "cdn-pool-sync" and not result.get("applied"):
                failed = result
                if args.json:
                    print(json.dumps(failed, ensure_ascii=False, indent=2))
                    result = None
                raise ClusterError("CDN 优选池应用失败，回滚状态：" + json_dumps(failed.get("rollback")))
        elif args.command == "action":
            payload_text = Path(args.payload_file).read_text(encoding="utf-8") if args.payload_file else args.payload
            payload = json.loads(payload_text)
            if not isinstance(payload, dict):
                raise ClusterError("payload 必须是 JSON 对象")
            result = send_action(cluster, args.node_id, args.action, payload)
            print(json.dumps(result, ensure_ascii=False, indent=2))
        elif args.command == "batch-action":
            payload_text = Path(args.payload_file).read_text(encoding="utf-8") if args.payload_file else args.payload
            payload = json.loads(payload_text)
            if not isinstance(payload, dict):
                raise ClusterError("payload 必须是 JSON 对象")
            result = batch_action(cluster, re.split(r"[,\s]+", args.nodes), args.action, payload)
            print(json.dumps(result, ensure_ascii=False, indent=2))
        elif args.command == "update-all":
            script_payload = json.loads(Path(args.script_payload).read_text(encoding="utf-8"))
            agent_payload = json.loads(Path(args.agent_payload).read_text(encoding="utf-8"))
            if not isinstance(script_payload, dict) or not isinstance(agent_payload, dict):
                raise ClusterError("更新载荷必须是 JSON 对象")
            payload = {"script": script_payload, "agent": agent_payload, "exclude": args.exclude}
            if cluster.load_config().get("role") == "master" or cluster.is_federation():
                result = distribute_cluster_update(cluster, payload)
            else:
                result = request_cluster_update(cluster, payload)
            print(f"集群更新目标版本：{result.get('version') or '未知'}")
            status_labels = {
                "updated": ("已更新", "32"), "current": ("本机当前", "32"),
                "source-current": ("发起机当前", "32"), "excluded": ("已排除", "33"),
                "failed": ("更新失败", "31"),
            }
            for number, item in sorted(result.get("nodes", {}).items(), key=lambda pair: int(pair[0])):
                status = str(item.get("status", "unknown"))
                label, color = status_labels.get(status, ("状态未知", "33"))
                print(terminal_color(f"服务器 {int(number):02d}：{label}", color))
                if status == "failed" and item.get("error"):
                    print(terminal_color("  原因：" + str(item["error"]), "31"))
            if not result.get("complete"):
                raise ClusterError("部分服务器更新失败：" + json_dumps(result.get("failures", {})))
            print("全部可用服务器已完成 Lun 主脚本与联动程序更新。")
        elif args.command == "set-location":
            row = cluster.node(args.node_id)
            country_code = normalize_country_code(args.country_code)
            if country_code == "ZZ":
                country_code = infer_country_code(args.region)
            if country_code == "ZZ":
                country_code = row["country_code"]
            country = args.country or COUNTRY_NAMES_ZH.get(country_code, row["country"])
            provider = args.provider or row["provider"]
            cluster.set_location(row["id"], country_code, country, args.region, args.city, provider)
            identity = push_node_identity(cluster, row["id"], propagate=cluster.is_federation())
            result = dict(cluster.node(row["id"]))
            result["propagation"] = identity.get("propagation", {})
            print("节点地区已更新。")
        elif args.command == "locate":
            result = cluster.geolocate(args.node_id)
            identity = push_node_identity(
                cluster, cluster.node(args.node_id)["id"], propagate=cluster.is_federation()
            )
            result["propagation"] = identity.get("propagation", {})
            print("自动地区识别完成。")
        elif args.command == "assign-user":
            node_ids = [item for item in args.nodes.split(",") if item]
            cluster.assign_user_nodes(args.user_id, node_ids)
            result = {"user_id": args.user_id, "nodes": node_ids}
            print("用户服务器授权已更新。")
        elif args.command == "sync-users":
            result = sync_cluster_users(cluster, args.node_id)
            print("主 VPS 用户、凭据、权限与订阅已同步。")
        elif args.command == "backup":
            password = read_password(args.password_file, "备份口令：")
            exporter = cluster.export_federation_backup if cluster.is_federation() else cluster.export_backup
            result = {"path": str(exporter(Path(args.path), password))}
            print("集群加密备份已创建：" + result["path"])
        elif args.command == "restore":
            password = read_password(args.password_file, "备份口令：")
            restore = cluster.restore_federation_backup if cluster.is_federation() else cluster.restore_backup
            result = restore(Path(args.path), password)
            print("集群备份已加载。")
        elif args.command == "federation-backup":
            password = read_password(args.password_file, "Federation backup password: ")
            result = {"path": str(cluster.export_federation_backup(Path(args.path), password))}
        elif args.command == "identity-backup":
            password = read_password(args.password_file, "Identity backup password: ")
            result = {"path": str(cluster.export_identity_backup(Path(args.path), password))}
        elif args.command == "federation-restore":
            password = read_password(args.password_file, "Federation backup password: ")
            result = cluster.restore_federation_backup(Path(args.path), password)
        elif args.command == "identity-restore":
            password = read_password(args.password_file, "Identity backup password: ")
            result = cluster.restore_identity_backup(Path(args.path), password)
            if not args.json:
                print("本机联邦身份备份已恢复。")
        elif args.command == "endpoint-reconcile":
            result = reconcile_federation_endpoint(cluster)
            if not args.json:
                if result.get("changed"):
                    print(f"联邦公布 IP 已从 {result['old_host']} 更新为 {result['new_host']}。")
                    pending = result.get("endpoint", {}).get("pending", {})
                    if pending:
                        print(terminal_color(f"仍有 {len(pending)} 个成员待后续补齐。", "33"))
                    else:
                        print(terminal_color("全部可达成员已收到新地址。", "32"))
                elif result.get("confirmed"):
                    print("联邦公布 IP 与实际公网 IP 一致，未产生广播。")
                else:
                    print(terminal_color("多个公网 IP 探测源未能达成一致，已保持原联邦地址。", "33"))
        elif args.command == "revocation-check":
            result = cluster.check_self_revocation()
            if not args.json:
                print("revoked federation identity cleaned" if result.get("cleaned") else
                      f"membership checked: {result.get('checked', 0)}")
        elif args.command == "status":
            result = {"config": cluster.load_config(), "nodes": cluster.nodes(),
                      "endpoint": cluster.endpoint_status(),
                      "database": cluster.db.connection.execute("PRAGMA integrity_check").fetchone()[0]}
            if not args.json:
                print(f"角色：{result['config'].get('role', 'disabled')}")
                print(f"节点 ID：{result['config'].get('node_id', '-')}")
                print(f"数据库：{result['database']}")
                endpoint = result["endpoint"]
                print(f"实际公网 IP：{endpoint.get('actual_ip') or '未确认'}")
                print(f"联邦公布 IP：{endpoint.get('advertised_ip') or '-'}")
                print(f"地址同步：{'已同步' if endpoint.get('synced') else '待同步'}")
                print(f"最近检查：{iso_time(endpoint.get('last_checked'))}")
                print(f"最近变更：{iso_time(endpoint.get('changed_at'))}")
                print("最近成功成员：" + (
                    "、".join(short_id(node_id) for node_id in endpoint.get("successful", {})) or "-"
                ))
                print("待补齐成员：" + (
                    "、".join(short_id(node_id) for node_id in endpoint.get("pending", {})) or "-"
                ))
                print_nodes(result["nodes"])
        elif args.command == "serve":
            serve(cluster)
        if args.json and result is not None:
            print(json.dumps(result, ensure_ascii=False, indent=2))
        return 0
    except (ClusterError, sqlite3.Error, OSError, json.JSONDecodeError, subprocess.SubprocessError) as exc:
        print(terminal_color(f"错误：{exc}", "31", stream=sys.stderr), file=sys.stderr)
        return 1
    finally:
        cluster.close()


if __name__ == "__main__":
    raise SystemExit(main())
