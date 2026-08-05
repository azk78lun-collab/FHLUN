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
from typing import Any, Iterable


VERSION = "0.1.0"
API_VERSION = 2
JOIN_TTL = 15 * 60
MAX_BODY = 4 * 1024 * 1024
ROLE_TRANSFER_CHUNK = 512 * 1024
ROLE_TRANSFER_MAX = 32 * 1024 * 1024
ROLE_TRANSFER_TTL = 15 * 60
BACKUP_MAGIC = b"LUNCLUSTER1\0"
BACKUP_KDF_ITERATIONS = 300_000
SUBSCRIPTION_FILES = ("jhsub.txt", "clmi.yaml", "sbox.json")

COUNTRY_NAMES_ZH = {
    "AU": "澳大利亚", "CA": "加拿大", "DE": "德国", "FR": "法国", "GB": "英国",
    "HK": "中国香港", "JP": "日本", "KR": "韩国", "NL": "荷兰", "SG": "新加坡",
    "TW": "中国台湾", "US": "美国",
}
CITY_NAMES_ZH = {
    "frankfurt": "法兰克福", "hong kong": "香港", "los angeles": "洛杉矶",
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
    "role.stage", "role.discard", "role.promote", "role.rollback", "role.finalize",
    "role.children-commit", "role.children-revert", "controller.prepare",
    "controller.commit", "controller.abort", "controller.reassign",
}


class ClusterError(RuntimeError):
    pass


def utc_now() -> int:
    return int(time.time())


def iso_time(value: int | None) -> str:
    if not value:
        return "-"
    return dt.datetime.fromtimestamp(value, dt.timezone.utc).strftime("%Y-%m-%d %H:%M UTC")


def json_dumps(value: Any) -> str:
    return json.dumps(value, ensure_ascii=False, sort_keys=True, separators=(",", ":"))


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
            CREATE INDEX IF NOT EXISTS audit_created_idx ON audit_log(created_at DESC);
            UPDATE schema_meta SET version=2;
            """
        )
        node_columns = {row[1] for row in self.connection.execute("PRAGMA table_info(nodes)")}
        if "server_number" not in node_columns:
            self.connection.execute("ALTER TABLE nodes ADD COLUMN server_number INTEGER NOT NULL DEFAULT 0")
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
            "SELECT * FROM nodes ORDER BY server_number,id"
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

    def _openssl(self, arguments: list[str], timeout: int = 60) -> subprocess.CompletedProcess[str]:
        executable = shutil.which("openssl")
        if not executable:
            raise ClusterError("服务器联动需要 OpenSSL")
        return self._run([executable, *arguments], timeout=timeout)

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
        cert = certificate or self.pki / "node.crt"
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
        if config.get("role") != "child":
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
                id,role,endpoint_host,endpoint_port,internal_port,remark,server_number,expected_uuid,country_code,
                country,region,city,provider,state,last_seen,last_success,snapshot_at,lun_version,
                api_version,created_at,updated_at) VALUES(?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)
                ON CONFLICT(id) DO UPDATE SET role=excluded.role,endpoint_host=excluded.endpoint_host,
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
                    node_id, role, host, port, internal, values["remark"], server_number, values["expected_uuid"],
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
        rows = self.db.connection.execute("SELECT * FROM nodes ORDER BY server_number,id").fetchall()
        return [{**dict(row), "number": int(row["server_number"])} for row in rows]

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
        self.record_snapshot(self.local_snapshot(profile_key), role="master")

    def ensure_profile(self, name: str, selector: str, profile_key: str = "legacy",
                       token: str = "") -> sqlite3.Row:
        now = utc_now()
        name = safe_label(name)
        row = self.db.connection.execute("SELECT * FROM profiles WHERE name=?", (name,)).fetchone()
        if row is None and token:
            row = self.db.connection.execute("SELECT * FROM profiles WHERE token=?", (token,)).fetchone()
        if row:
            with self.db.connection:
                self.db.connection.execute(
                    "UPDATE profiles SET name=?,selector=?,profile_key=?,enabled=1,updated_at=? WHERE id=?",
                    (name, selector, safe_slug(profile_key), now, row["id"]),
                )
            return self.db.connection.execute("SELECT * FROM profiles WHERE id=?", (row["id"],)).fetchone()
        profile_token = token or b64url(secrets.token_bytes(24))
        if not re.fullmatch(r"[A-Za-z0-9_-]{16,128}", profile_token):
            raise ClusterError("订阅 token 无效")
        with self.db.connection:
            self.db.connection.execute(
                "INSERT INTO profiles(name,token,selector,profile_key,created_at,updated_at) VALUES(?,?,?,?,?,?)",
                (name, profile_token, selector, safe_slug(profile_key), now, now),
            )
        return self.db.connection.execute("SELECT * FROM profiles WHERE name=?", (name,)).fetchone()

    def profiles(self) -> list[dict[str, Any]]:
        return [dict(row) for row in self.db.connection.execute(
            "SELECT * FROM profiles WHERE enabled=1 ORDER BY id"
        )]

    def refresh_profiles(self, profile_key: str = "legacy") -> list[dict[str, Any]]:
        config = self.load_config()
        if config.get("role") == "master":
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
            if config.get("role") == "master":
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
                archive.extractall(extract)
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
                    archive.extractall(extract)
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
                archive.extractall(extract)
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
                tar.extractall(extract)
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


def print_nodes(rows: list[dict[str, Any]]) -> None:
    headers = ("编号", "状态", "类型", "地区", "地址", "备注", "快照")
    values: list[tuple[str, ...]] = []
    place_labels = numbered_place_labels(rows)
    for row in rows:
        values.append((
            f"{int(row.get('number', len(values) + 1)):02d}", STATE_NAMES_ZH.get(row["state"], "异常"),
            "主机" if row["role"] == "master" else "子机",
            place_labels.get(str(row.get("id", "")), chinese_place(row)),
            f"{uri_host(row['endpoint_host'])}:{row['endpoint_port']}", row["remark"] or "-",
            iso_time(row["snapshot_at"]),
        ))
    widths = [display_width(item) for item in headers]
    for row in values:
        widths = [max(old, display_width(item)) for old, item in zip(widths, row)]
    print("  ".join(display_pad(item, width) for item, width in zip(headers, widths)))
    for row in values:
        print("  ".join(display_pad(item, width) for item, width in zip(row, widths)))


def _peer_common_name(handler: http.server.BaseHTTPRequestHandler) -> str:
    with contextlib.suppress(ValueError, ssl.SSLError):
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

    def _reply(self, status: int, value: dict[str, Any]) -> None:
        payload = json.dumps(value, ensure_ascii=False, separators=(",", ":")).encode()
        self.send_response(status)
        self.send_header("Content-Type", "application/json; charset=utf-8")
        self.send_header("Content-Length", str(len(payload)))
        self.send_header("Cache-Control", "no-store")
        self.send_header("X-Content-Type-Options", "nosniff")
        self.end_headers()
        self.wfile.write(payload)

    def _require_peer(self) -> str:
        common_name = _peer_common_name(self)
        if not re.fullmatch(r"[0-9a-f]{32}", common_name):
            raise ClusterError("需要有效的集群客户端证书")
        config = self.cluster.load_config()
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
            if parsed.path == "/v1/bootstrap/csr":
                self._bootstrap_csr(parsed)
                return
            self._require_peer()
            if parsed.path == "/v1/status":
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
            peer = self._require_peer()
            if parsed.path == "/v1/events/snapshot":
                if self.cluster.load_config().get("role") != "master":
                    raise ClusterError("当前节点不是主 VPS")
                snapshot = body.get("snapshot", {})
                status = snapshot.get("status", {}) if isinstance(snapshot, dict) else {}
                if status.get("node_id") != peer:
                    raise ClusterError("订阅快照节点身份不匹配")
                self.cluster.record_snapshot(snapshot)
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
        if config.get("role") != "child" or config.get("paired"):
            raise ClusterError("该子 VPS 已经完成配对")
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
        if config.get("role") != "child" or config.get("paired"):
            raise ClusterError("该子 VPS 已经完成配对")
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
        self.cluster.db.audit("cluster.paired", controller_id, f"{host}:{port}")
        self._reply(200, {"ok": True, "snapshot": self.cluster.local_snapshot(),
                          "identity_rebuild_error": rebuild_error, "restart_required": True})
        self.server.restart_requested = True  # type: ignore[attr-defined]

    def log_message(self, fmt: str, *args: Any) -> None:
        # Paths can contain one-time join tokens; never write request paths.
        sys.stderr.write(f"cluster {self.client_address[0]} {args[1] if len(args) > 1 else ''}\n")


class ThreadingClusterServer(http.server.ThreadingHTTPServer):
    daemon_threads = True
    allow_reuse_address = True


def server_context(cluster: Cluster) -> ssl.SSLContext:
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
    if not config.get("enabled") or config.get("role") not in {"master", "child"}:
        raise ClusterError("服务器联动模块尚未启用")
    bind = config.get("bind", "0.0.0.0")
    port = int(config.get("internal_port", 0))
    if not valid_port(port):
        raise ClusterError("服务器联动监听端口无效")
    server = ThreadingClusterServer((bind, port), ClusterHandler)
    server.cluster = cluster  # type: ignore[attr-defined]
    server.restart_requested = False  # type: ignore[attr-defined]
    server.socket = server_context(cluster).wrap_socket(server.socket, server_side=True)
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


def bootstrap_request(join: dict[str, Any], method: str, path: str, body: dict[str, Any] | None = None) -> dict[str, Any]:
    context = ssl._create_unverified_context()  # fingerprint pinning below is the trust decision
    connection = http.client.HTTPSConnection(join["host"], join["port"], context=context, timeout=15)
    connection.connect()
    certificate = connection.sock.getpeercert(binary_form=True)  # type: ignore[union-attr]
    fingerprint = hashlib.sha256(certificate).hexdigest()
    if not hmac.compare_digest(fingerprint, join["fingerprint"]):
        connection.close()
        raise ClusterError("子 VPS TLS 指纹与加入地址不一致")
    payload = json.dumps(body, ensure_ascii=False).encode() if body is not None else None
    headers = {"Content-Type": "application/json"} if payload is not None else {}
    connection.request(method, path, body=payload, headers=headers)
    response = connection.getresponse()
    data = response.read(MAX_BODY + 1)
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
    context = ssl.create_default_context(ssl.Purpose.SERVER_AUTH, cafile=str(cluster.pki / "cluster-ca.crt"))
    context.check_hostname = False
    context.minimum_version = ssl.TLSVersion.TLSv1_2
    context.load_cert_chain(str(cluster.pki / "node.crt"), str(cluster.pki / "node.key"))
    connection = http.client.HTTPSConnection(host, int(port), context=context, timeout=timeout)
    payload = json.dumps(body, ensure_ascii=False).encode() if body is not None else None
    headers = {"Content-Type": "application/json"} if payload is not None else {}
    try:
        connection.request(method, path, body=payload, headers=headers)
        response = connection.getresponse()
        data = response.read(MAX_BODY + 1)
    except (OSError, ssl.SSLError, TimeoutError) as exc:
        raise ClusterError(f"无法连接服务器联动端口：{exc}") from exc
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


def add_node(cluster: Cluster, join_uri: str, remark: str = "", expected_uuid: str = "") -> dict[str, Any]:
    config = cluster.load_config()
    if config.get("role") != "master":
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


def push_node_identity(cluster: Cluster, node_id: str) -> dict[str, Any]:
    row = cluster.node(node_id)
    location = {key: row[key] for key in ("country_code", "country", "region", "city", "provider")}
    place = cluster.identity_place(row)
    if row["role"] == "master":
        identity = cluster.apply_identity_transaction(int(row["server_number"]), location, place)
        cluster.record_local_snapshot()
        cluster.mark_identity_synced(cluster.node(str(row["id"])))
        return {"identity": identity, "snapshot": cluster.local_snapshot()}
    result = send_action(cluster, row["id"], "identity.apply", {
        "server_number": int(row["server_number"]), "location": location, "place": place,
    })
    payload = result.get("result") if isinstance(result.get("result"), dict) else {}
    remote_identity = payload.get("identity") if isinstance(payload.get("identity"), dict) else {}
    if safe_label(str(remote_identity.get("place", "")), 48) != place:
        raise ClusterError("子 VPS 未应用同地区编号，请先更新该节点的 Lun 联动模块")
    snapshot = payload.get("snapshot") if isinstance(payload.get("snapshot"), dict) else None
    if snapshot:
        cluster.record_snapshot(snapshot)
    cluster.mark_identity_synced(cluster.node(str(row["id"])))
    return result


def push_snapshot(cluster: Cluster, profile: str = "legacy") -> dict[str, Any]:
    config = cluster.load_config()
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


def _execute_action_locked(cluster: Cluster, action: str, payload: dict[str, Any], request: dict[str, Any],
                           peer_id: str = "local") -> dict[str, Any]:
    script = Path(os.environ.get("LUN_SCRIPT", "/usr/bin/lun"))
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
        return {"identity": identity, "snapshot": cluster.local_snapshot()}
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
    if action == "script.install":
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
        return {"sha256": expected, "path": str(script)}
    if action == "agent.install":
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
        destination = Path(__file__).resolve()
        with tempfile.NamedTemporaryFile(dir=str(destination.parent), delete=False) as handle:
            handle.write(content)
            temporary = Path(handle.name)
        try:
            os.chmod(temporary, 0o755)
            backup = destination.with_name(destination.name + ".cluster-backup")
            shutil.copy2(destination, backup)
            os.replace(temporary, destination)
        finally:
            temporary.unlink(missing_ok=True)
        return {"sha256": expected, "path": str(destination), "restart_required": True}
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


def send_action(cluster: Cluster, node_id: str, action: str, payload: dict[str, Any]) -> dict[str, Any]:
    node = cluster.node(node_id)
    if action in {"lun.factory-reset", "lun.uninstall"} and str(payload.get("confirm", "")) == node_id:
        payload = {**payload, "confirm": short_id(node["id"])}
    request = {"schema_version": API_VERSION, "request_id": uuid.uuid4().hex, "action": action, "payload": payload}
    result = mutual_request(cluster, node["endpoint_host"], node["endpoint_port"], "POST", "/v1/action", request, timeout=900)
    return result["result"]


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


def sync_cluster_users(cluster: Cluster, only_node: str = "") -> dict[str, Any]:
    config = cluster.load_config()
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
    sub.add_parser("profiles")
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
            if args.confirm != f"SWITCH-{number}":
                raise ClusterError(f"确认文字不匹配，请输入 SWITCH-{number}")
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
            result = sync_node(cluster, args.node_id, args.profile)
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
        elif args.command == "profiles":
            result = cluster.profiles()
            if not args.json:
                for item in result:
                    print(f"{item['id']}. {item['name']}  selector={item['selector']}  token={item['token']}")
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
            push_node_identity(cluster, row["id"])
            result = dict(cluster.node(row["id"]))
            print("节点地区已更新。")
        elif args.command == "locate":
            result = cluster.geolocate(args.node_id)
            push_node_identity(cluster, cluster.node(args.node_id)["id"])
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
            result = {"path": str(cluster.export_backup(Path(args.path), password))}
            print("集群加密备份已创建：" + result["path"])
        elif args.command == "restore":
            password = read_password(args.password_file, "备份口令：")
            result = cluster.restore_backup(Path(args.path), password)
            print("集群备份已加载。")
        elif args.command == "status":
            result = {"config": cluster.load_config(), "nodes": cluster.nodes(),
                      "database": cluster.db.connection.execute("PRAGMA integrity_check").fetchone()[0]}
            if not args.json:
                print(f"角色：{result['config'].get('role', 'disabled')}")
                print(f"节点 ID：{result['config'].get('node_id', '-')}")
                print(f"数据库：{result['database']}")
                print_nodes(result["nodes"])
        elif args.command == "serve":
            serve(cluster)
        if args.json and result is not None:
            print(json.dumps(result, ensure_ascii=False, indent=2))
        return 0
    except (ClusterError, sqlite3.Error, OSError, json.JSONDecodeError, subprocess.SubprocessError) as exc:
        print(f"错误：{exc}", file=sys.stderr)
        return 1
    finally:
        cluster.close()


if __name__ == "__main__":
    raise SystemExit(main())
