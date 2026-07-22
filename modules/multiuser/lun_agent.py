#!/usr/bin/env python3
"""FHLUN optional multi-user agent.

The agent deliberately has no third-party Python dependencies.  It owns only
multi-user state, subscription delivery and the additive portions of core
configuration.  lun.sh remains the source of truth for protocols, ports,
certificates, CDN, NAT and WARP.
"""

from __future__ import annotations

import argparse
import base64
import contextlib
import copy
import datetime as dt
import hashlib
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
import tempfile
import threading
import time
import unicodedata
import urllib.parse
from pathlib import Path
from typing import Any, Iterable


VERSION = "0.1.0"
PROTOCOLS = (
    "vl", "xh", "vx", "vw", "ss", "an", "ar", "vm", "so", "hy", "tu", "xu", "xc", "nv"
)
PROTOCOL_LABELS = {
    "vl": "VLESS TCP Reality",
    "xh": "VLESS XHTTP Reality",
    "vx": "VLESS XHTTP",
    "vw": "VLESS WS",
    "ss": "Shadowsocks-2022",
    "an": "AnyTLS",
    "ar": "Any-Reality",
    "vm": "VMess WS",
    "so": "Socks5",
    "hy": "Hysteria2",
    "tu": "TUIC",
    "xu": "VLESS XHTTP TLS UDP",
    "xc": "VLESS XHTTP TLS TCP/UDP",
    "nv": "NaiveProxy",
}
XRAY_TAG_PROTOCOL = {
    "reality-vision": "vl",
    "xhttp-reality": "xh",
    "vless-xhttp": "vx",
    "vless-ws": "vw",
    "vmess-xr": "vm",
    "socks5-xr": "so",
    "xhttp-h3": "xu",
    "xhttp-h23": "xc",
}
SINGBOX_TAG_PROTOCOL = {
    "ss-2022": "ss",
    "ss-2022-mu": "ss",
    "anytls-sb": "an",
    "anyreality-sb": "ar",
    "vmess-sb": "vm",
    "socks5-sb": "so",
    "hy2-sb": "hy",
    "tuic5-sb": "tu",
    "naive-sb": "nv",
}
PRIVATE_CIDRS = [
    "0.0.0.0/8", "10.0.0.0/8", "100.64.0.0/10", "127.0.0.0/8",
    "169.254.0.0/16", "172.16.0.0/12", "192.0.0.0/24", "192.168.0.0/16",
    "198.18.0.0/15", "224.0.0.0/4", "240.0.0.0/4", "::1/128",
    "fc00::/7", "fe80::/10", "ff00::/8",
]
BLOCKED_METADATA_DOMAINS = [
    "metadata.google.internal", "metadata.azure.internal", "instance-data.ec2.internal"
]


class AgentError(RuntimeError):
    pass


def utc_now() -> int:
    return int(time.time())


def iso_time(value: int | None) -> str:
    if not value:
        return "永不过期"
    return dt.datetime.fromtimestamp(value, dt.timezone.utc).strftime("%Y-%m-%d %H:%M UTC")


def parse_expiry(value: str | None) -> int | None:
    if not value or value.lower() in {"0", "none", "never", "永久"}:
        return None
    for fmt in ("%Y-%m-%d", "%Y-%m-%dT%H:%M", "%Y-%m-%d %H:%M"):
        try:
            parsed = dt.datetime.strptime(value, fmt).replace(tzinfo=dt.timezone.utc)
            if fmt == "%Y-%m-%d":
                parsed += dt.timedelta(days=1)
            return int(parsed.timestamp())
        except ValueError:
            pass
    raise AgentError("到期时间格式应为 YYYY-MM-DD、YYYY-MM-DDTHH:MM 或 never")


def parse_size(value: str | int | None) -> int:
    if value is None:
        return 0
    if isinstance(value, int):
        return max(0, value)
    raw = value.strip().lower().replace("ib", "b")
    if raw in {"", "0", "none", "unlimited", "不限"}:
        return 0
    match = re.fullmatch(r"([0-9]+(?:\.[0-9]+)?)\s*([kmgtp]?b?)?", raw)
    if not match:
        raise AgentError(f"无法识别流量值：{value}")
    number = float(match.group(1))
    unit = (match.group(2) or "b").rstrip("b")
    power = {"": 0, "k": 1, "m": 2, "g": 3, "t": 4, "p": 5}[unit]
    return int(number * (1024 ** power))


def format_size(value: int) -> str:
    if value <= 0:
        return "不限"
    number = float(value)
    for unit in ("B", "KiB", "MiB", "GiB", "TiB", "PiB"):
        if number < 1024 or unit == "PiB":
            return f"{number:.2f} {unit}"
        number /= 1024
    return f"{value} B"


def format_gib(value: int) -> str:
    return f"{max(0, value) / (1024 ** 3):.2f}G"


def display_width(value: str) -> int:
    return sum(2 if unicodedata.east_asian_width(char) in {"W", "F"} else 1 for char in value)


def display_pad(value: str, width: int) -> str:
    return value + " " * max(0, width - display_width(value))


def print_status_table(rows: list[dict[str, Any]]) -> None:
    headers = ("ID", "状态", "设备", "已用/月额度", "到期", "名称")
    values: list[tuple[str, ...]] = []
    for row in rows:
        state = "正常" if row["active"] else row["reason"]
        quota = format_gib(row["monthly_quota"]) if row["monthly_quota"] else "不限"
        expires = iso_time(row["expires_at"]).split(" ", 1)[0] if row["expires_at"] else "永久"
        values.append((
            str(row["id"]), state, f"{row['devices']}/{row['max_devices']}",
            f"{format_gib(row['monthly'])}/{quota}", expires, row["name"],
        ))
    widths = [display_width(header) for header in headers]
    for row in values:
        widths = [max(current, display_width(value)) for current, value in zip(widths, row)]
    print("  ".join(display_pad(value, width) for value, width in zip(headers, widths)))
    for row in values:
        print("  ".join(display_pad(value, width) for value, width in zip(row, widths)))


def atomic_write(path: Path, data: str | bytes, mode: int = 0o600) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    payload = data.encode("utf-8") if isinstance(data, str) else data
    fd, tmp_name = tempfile.mkstemp(prefix=f".{path.name}.", dir=str(path.parent))
    try:
        with os.fdopen(fd, "wb") as handle:
            handle.write(payload)
            handle.flush()
            os.fsync(handle.fileno())
        os.chmod(tmp_name, mode)
        os.replace(tmp_name, path)
    finally:
        with contextlib.suppress(FileNotFoundError):
            os.unlink(tmp_name)


class FileLock:
    def __init__(self, path: Path, timeout: float = 15.0):
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
                try:
                    if utc_now() - int(self.path.stat().st_mtime) > 120:
                        self.path.unlink()
                        continue
                except (FileNotFoundError, OSError):
                    continue
                if time.monotonic() >= deadline:
                    raise AgentError("多用户模块正被另一项操作占用")
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
            connection = sqlite3.connect(self.path, timeout=15)
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
            CREATE TABLE IF NOT EXISTS schema_meta (
              version INTEGER NOT NULL
            );
            INSERT INTO schema_meta(version)
              SELECT 1 WHERE NOT EXISTS (SELECT 1 FROM schema_meta);
            CREATE TABLE IF NOT EXISTS users (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              name TEXT NOT NULL UNIQUE COLLATE NOCASE,
              manual_disabled INTEGER NOT NULL DEFAULT 0,
              lifetime_quota INTEGER NOT NULL DEFAULT 0,
              monthly_quota INTEGER NOT NULL DEFAULT 0,
              reset_day INTEGER NOT NULL DEFAULT 1 CHECK(reset_day BETWEEN 1 AND 28),
              expires_at INTEGER,
              max_devices INTEGER NOT NULL DEFAULT 3 CHECK(max_devices BETWEEN 1 AND 64),
              created_at INTEGER NOT NULL,
              updated_at INTEGER NOT NULL
            );
            CREATE TABLE IF NOT EXISTS devices (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              user_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
              name TEXT NOT NULL,
              uuid TEXT NOT NULL UNIQUE,
              password TEXT NOT NULL,
              ss_password TEXT NOT NULL,
              token TEXT NOT NULL UNIQUE,
              enabled INTEGER NOT NULL DEFAULT 1,
              legacy INTEGER NOT NULL DEFAULT 0,
              created_at INTEGER NOT NULL,
              updated_at INTEGER NOT NULL,
              UNIQUE(user_id, name COLLATE NOCASE)
            );
            CREATE TABLE IF NOT EXISTS protocol_permissions (
              user_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
              protocol TEXT NOT NULL,
              enabled INTEGER NOT NULL DEFAULT 1,
              PRIMARY KEY(user_id, protocol)
            );
            CREATE TABLE IF NOT EXISTS usage_totals (
              device_id INTEGER NOT NULL REFERENCES devices(id) ON DELETE CASCADE,
              core TEXT NOT NULL,
              uplink INTEGER NOT NULL DEFAULT 0,
              downlink INTEGER NOT NULL DEFAULT 0,
              month_uplink INTEGER NOT NULL DEFAULT 0,
              month_downlink INTEGER NOT NULL DEFAULT 0,
              period_start TEXT NOT NULL,
              updated_at INTEGER NOT NULL,
              PRIMARY KEY(device_id, core)
            );
            CREATE TABLE IF NOT EXISTS runtime_state (
              device_id INTEGER PRIMARY KEY REFERENCES devices(id) ON DELETE CASCADE,
              active INTEGER NOT NULL,
              reason TEXT NOT NULL,
              updated_at INTEGER NOT NULL
            );
            CREATE TABLE IF NOT EXISTS settings (
              key TEXT PRIMARY KEY,
              value TEXT NOT NULL
            );
            CREATE TABLE IF NOT EXISTS audit_log (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              created_at INTEGER NOT NULL,
              action TEXT NOT NULL,
              target TEXT NOT NULL,
              detail TEXT NOT NULL DEFAULT ''
            );
            """
        )
        self.connection.commit()

    def audit(self, action: str, target: str, detail: str = "") -> None:
        self.connection.execute(
            "INSERT INTO audit_log(created_at,action,target,detail) VALUES(?,?,?,?)",
            (utc_now(), action, target, detail[:1000]),
        )

    def set_setting(self, key: str, value: str | int) -> None:
        self.connection.execute(
            "INSERT INTO settings(key,value) VALUES(?,?) "
            "ON CONFLICT(key) DO UPDATE SET value=excluded.value",
            (key, str(value)),
        )

    def setting(self, key: str, default: str = "") -> str:
        row = self.connection.execute("SELECT value FROM settings WHERE key=?", (key,)).fetchone()
        return row[0] if row else default


class Agent:
    def __init__(self, root: Path):
        self.root = root.expanduser().resolve()
        self.module = self.root / "modules" / "multiuser"
        self.data_dir = self.module / "data"
        self.generated = self.module / "generated"
        self.backups = self.module / "backups"
        self.config_path = self.module / "config.json"
        self.lock_path = self.module / ".lock"
        self.db = Database(self.data_dir / "lun.db")
        self.db.migrate()

    def close(self) -> None:
        self.db.close()

    def load_config(self) -> dict[str, Any]:
        if not self.config_path.exists():
            raise AgentError("多用户模块尚未初始化")
        with self.config_path.open("r", encoding="utf-8") as handle:
            return json.load(handle)

    def save_config(self, config: dict[str, Any]) -> None:
        atomic_write(self.config_path, json.dumps(config, ensure_ascii=False, indent=2) + "\n")

    def initialize(self, args: argparse.Namespace) -> dict[str, Any]:
        self.module.mkdir(parents=True, exist_ok=True)
        self.generated.mkdir(parents=True, exist_ok=True)
        self.backups.mkdir(parents=True, exist_ok=True)
        legacy_uuid = args.legacy_uuid or self._read_text("uuid") or str(__import__("uuid").uuid4())
        legacy_token = args.legacy_token or self._read_text("subtoken.log") or legacy_uuid
        config = {
            "version": VERSION,
            "enabled": True,
            "bind": args.bind,
            "port": args.port,
            "public_port": args.public_port or args.port,
            "legacy_http_port": max(0, args.legacy_http_port),
            "legacy_http_public_port": max(0, args.legacy_http_public_port or args.legacy_http_port),
            "scheme": args.scheme,
            "public_host": args.public_host,
            "certificate": args.certificate or "",
            "private_key": args.private_key or "",
            "xray_api": args.xray_api,
            "singbox_api": args.singbox_api,
            "poll_interval": max(15, args.poll_interval),
            "legacy_uuid": legacy_uuid,
            "legacy_token": legacy_token,
            "ss_port": max(0, args.ss_port),
            "ss_public_port": max(0, args.ss_public_port or args.ss_port),
            "ss_server_password": args.ss_server_password or base64.b64encode(secrets.token_bytes(16)).decode(),
        }
        if args.scheme == "https":
            if not (config["certificate"] and config["private_key"]):
                raise AgentError("HTTPS 订阅缺少证书或私钥")
            if not Path(config["certificate"]).is_file() or not Path(config["private_key"]).is_file():
                raise AgentError("HTTPS 订阅证书文件不存在")
        self.save_config(config)
        now = utc_now()
        row = self.db.connection.execute("SELECT id FROM users WHERE name='legacy-admin'").fetchone()
        if row:
            user_id = row[0]
        else:
            cursor = self.db.connection.execute(
                "INSERT INTO users(name,reset_day,max_devices,created_at,updated_at) VALUES(?,?,?,?,?)",
                ("legacy-admin", 1, 3, now, now),
            )
            user_id = cursor.lastrowid
            self._insert_protocol_defaults(user_id)
        device = self.db.connection.execute(
            "SELECT id FROM devices WHERE user_id=? AND legacy=1", (user_id,)
        ).fetchone()
        if not device:
            self.db.connection.execute(
                "INSERT INTO devices(user_id,name,uuid,password,ss_password,token,enabled,legacy,created_at,updated_at) "
                "VALUES(?,?,?,?,?,?,?,?,?,?)",
                (user_id, "legacy-device", legacy_uuid, legacy_uuid,
                 base64.b64encode(secrets.token_bytes(16)).decode(), legacy_token, 1, 1, now, now),
            )
        self.db.audit("module.init", "module", f"scheme={args.scheme},port={args.port}")
        self.db.connection.commit()
        self.backup_database()
        return config

    def _read_text(self, name: str) -> str:
        try:
            return (self.root / name).read_text(encoding="utf-8").strip()
        except OSError:
            return ""

    def _insert_protocol_defaults(self, user_id: int) -> None:
        self.db.connection.executemany(
            "INSERT OR IGNORE INTO protocol_permissions(user_id,protocol,enabled) VALUES(?,?,1)",
            ((user_id, protocol) for protocol in PROTOCOLS),
        )

    def add_user(self, args: argparse.Namespace) -> sqlite3.Row:
        now = utc_now()
        with self.db.connection:
            cursor = self.db.connection.execute(
                "INSERT INTO users(name,lifetime_quota,monthly_quota,reset_day,expires_at,max_devices,created_at,updated_at) "
                "VALUES(?,?,?,?,?,?,?,?)",
                (args.name.strip(), parse_size(args.lifetime_quota), parse_size(args.monthly_quota),
                 args.reset_day, parse_expiry(args.expires), args.max_devices, now, now),
            )
            user_id = cursor.lastrowid
            self._insert_protocol_defaults(user_id)
            device = self._create_device(user_id, args.device_name or "device-1")
            self.db.audit("user.add", str(user_id), args.name)
        self.backup_database()
        return device

    def _create_device(self, user_id: int, name: str) -> sqlite3.Row:
        user = self.db.connection.execute("SELECT * FROM users WHERE id=?", (user_id,)).fetchone()
        if not user:
            raise AgentError("用户不存在")
        count = self.db.connection.execute(
            "SELECT COUNT(*) FROM devices WHERE user_id=?", (user_id,)
        ).fetchone()[0]
        if count >= user["max_devices"]:
            raise AgentError(f"设备数已达到上限 {user['max_devices']}")
        now = utc_now()
        device_uuid = str(__import__("uuid").uuid4())
        password = secrets.token_urlsafe(18)
        ss_password = base64.b64encode(secrets.token_bytes(16)).decode()
        token = secrets.token_urlsafe(24)
        cursor = self.db.connection.execute(
            "INSERT INTO devices(user_id,name,uuid,password,ss_password,token,created_at,updated_at) "
            "VALUES(?,?,?,?,?,?,?,?)",
            (user_id, name.strip(), device_uuid, password, ss_password, token, now, now),
        )
        return self.db.connection.execute("SELECT * FROM devices WHERE id=?", (cursor.lastrowid,)).fetchone()

    def add_device(self, user_id: int, name: str) -> sqlite3.Row:
        with self.db.connection:
            device = self._create_device(user_id, name)
            self.db.audit("device.add", str(device["id"]), f"user={user_id}")
        self.backup_database()
        return device

    def update_device(self, device_id: int, name: str | None = None, enabled: bool | None = None) -> sqlite3.Row:
        device = self.db.connection.execute("SELECT * FROM devices WHERE id=?", (device_id,)).fetchone()
        if not device:
            raise AgentError("设备不存在")
        new_name = name.strip() if name is not None else device["name"]
        if not new_name:
            raise AgentError("设备名称不能为空")
        new_enabled = int(enabled) if enabled is not None else device["enabled"]
        with self.db.connection:
            self.db.connection.execute(
                "UPDATE devices SET name=?,enabled=?,updated_at=? WHERE id=?",
                (new_name, new_enabled, utc_now(), device_id),
            )
            self.db.audit("device.update", str(device_id), f"name={new_name},enabled={new_enabled}")
        self.backup_database()
        return self.db.connection.execute("SELECT * FROM devices WHERE id=?", (device_id,)).fetchone()

    def rotate_device(self, device_id: int, confirmation: str) -> sqlite3.Row:
        device = self.db.connection.execute("SELECT * FROM devices WHERE id=?", (device_id,)).fetchone()
        if not device:
            raise AgentError("设备不存在")
        if confirmation != device["name"]:
            raise AgentError("确认名称不匹配，未轮换")
        old_token = device["token"]
        values = (
            str(__import__("uuid").uuid4()),
            secrets.token_urlsafe(18),
            base64.b64encode(secrets.token_bytes(16)).decode(),
            secrets.token_urlsafe(24),
            utc_now(),
            device_id,
        )
        with self.db.connection:
            self.db.connection.execute(
                "UPDATE devices SET uuid=?,password=?,ss_password=?,token=?,legacy=0,updated_at=? WHERE id=?",
                values,
            )
            self.db.audit("device.rotate", str(device_id), device["name"])
        shutil.rmtree(self.generated / old_token, ignore_errors=True)
        self._replace_security_backups()
        return self.db.connection.execute("SELECT * FROM devices WHERE id=?", (device_id,)).fetchone()

    def delete_device(self, device_id: int, confirmation: str) -> None:
        device = self.db.connection.execute("SELECT * FROM devices WHERE id=?", (device_id,)).fetchone()
        if not device:
            raise AgentError("设备不存在")
        if confirmation != device["name"]:
            raise AgentError("确认名称不匹配，未删除")
        with self.db.connection:
            self.db.audit("device.delete", str(device_id), device["name"])
            self.db.connection.execute("DELETE FROM devices WHERE id=?", (device_id,))
        shutil.rmtree(self.generated / device["token"], ignore_errors=True)
        self._replace_security_backups()

    def update_user(self, args: argparse.Namespace) -> None:
        row = self.db.connection.execute("SELECT * FROM users WHERE id=?", (args.user_id,)).fetchone()
        if not row:
            raise AgentError("用户不存在")
        values = dict(row)
        if args.lifetime_quota is not None:
            values["lifetime_quota"] = parse_size(args.lifetime_quota)
        if args.monthly_quota is not None:
            values["monthly_quota"] = parse_size(args.monthly_quota)
        if args.reset_day is not None:
            values["reset_day"] = args.reset_day
        if args.expires is not None:
            values["expires_at"] = parse_expiry(args.expires)
        if args.max_devices is not None:
            values["max_devices"] = args.max_devices
        if args.enabled is not None:
            values["manual_disabled"] = 0 if args.enabled else 1
        with self.db.connection:
            self.db.connection.execute(
                "UPDATE users SET manual_disabled=?,lifetime_quota=?,monthly_quota=?,reset_day=?,"
                "expires_at=?,max_devices=?,updated_at=? WHERE id=?",
                (values["manual_disabled"], values["lifetime_quota"], values["monthly_quota"],
                 values["reset_day"], values["expires_at"], values["max_devices"], utc_now(), args.user_id),
            )
            self.db.audit("user.update", str(args.user_id))
        self.backup_database()

    def set_protocol(self, user_id: int, protocol: str, enabled: bool) -> None:
        if protocol not in PROTOCOLS:
            raise AgentError(f"未知协议：{protocol}")
        if not self.db.connection.execute("SELECT 1 FROM users WHERE id=?", (user_id,)).fetchone():
            raise AgentError("用户不存在")
        with self.db.connection:
            self.db.connection.execute(
                "INSERT INTO protocol_permissions(user_id,protocol,enabled) VALUES(?,?,?) "
                "ON CONFLICT(user_id,protocol) DO UPDATE SET enabled=excluded.enabled",
                (user_id, protocol, int(enabled)),
            )
            self.db.audit("protocol.set", str(user_id), f"{protocol}={int(enabled)}")
        self.backup_database()

    def delete_user(self, user_id: int, confirmation: str) -> None:
        user = self.db.connection.execute("SELECT * FROM users WHERE id=?", (user_id,)).fetchone()
        if not user:
            raise AgentError("用户不存在")
        if confirmation != user["name"]:
            raise AgentError("确认名称不匹配，未删除")
        tokens = [
            row["token"]
            for row in self.db.connection.execute("SELECT token FROM devices WHERE user_id=?", (user_id,))
        ]
        with self.db.connection:
            self.db.audit("user.delete", str(user_id), user["name"])
            self.db.connection.execute("DELETE FROM users WHERE id=?", (user_id,))
        self.db.connection.execute("VACUUM")
        for token in tokens:
            shutil.rmtree(self.generated / token, ignore_errors=True)
        self._replace_security_backups()

    def _replace_security_backups(self) -> None:
        for backup in self.backups.glob("db-*.sqlite3"):
            backup.unlink(missing_ok=True)
        self.backup_database()

    def month_period(self, reset_day: int, now: dt.datetime | None = None) -> str:
        current = now or dt.datetime.now(dt.timezone.utc)
        if current.day >= reset_day:
            start = current.replace(day=reset_day, hour=0, minute=0, second=0, microsecond=0)
        else:
            previous = current.replace(day=1) - dt.timedelta(days=1)
            start = previous.replace(day=reset_day, hour=0, minute=0, second=0, microsecond=0)
        return start.strftime("%Y-%m-%d")

    def reset_month_periods(self) -> bool:
        changed = False
        rows = self.db.connection.execute(
            "SELECT u.reset_day,d.id FROM devices d JOIN users u ON u.id=d.user_id"
        ).fetchall()
        with self.db.connection:
            for row in rows:
                period = self.month_period(row["reset_day"])
                result = self.db.connection.execute(
                    "UPDATE usage_totals SET month_uplink=0,month_downlink=0,period_start=?,updated_at=? "
                    "WHERE device_id=? AND period_start<>?",
                    (period, utc_now(), row["id"], period),
                )
                changed = changed or result.rowcount > 0
        return changed

    def usage_for_user(self, user_id: int) -> tuple[int, int]:
        row = self.db.connection.execute(
            "SELECT COALESCE(SUM(t.uplink+t.downlink),0) lifetime,"
            "COALESCE(SUM(t.month_uplink+t.month_downlink),0) monthly "
            "FROM devices d LEFT JOIN usage_totals t ON t.device_id=d.id WHERE d.user_id=?",
            (user_id,),
        ).fetchone()
        return int(row["lifetime"]), int(row["monthly"])

    def effective_user(self, user: sqlite3.Row) -> tuple[bool, str]:
        if user["manual_disabled"]:
            return False, "管理员停用"
        if user["expires_at"] and utc_now() >= user["expires_at"]:
            return False, "已到期"
        lifetime, monthly = self.usage_for_user(user["id"])
        if user["lifetime_quota"] and lifetime >= user["lifetime_quota"]:
            return False, "永久流量已用尽"
        if user["monthly_quota"] and monthly >= user["monthly_quota"]:
            return False, "本月流量已用尽"
        return True, "正常"

    def active_devices(self) -> list[dict[str, Any]]:
        permissions = {
            row["user_id"]: {} for row in self.db.connection.execute("SELECT DISTINCT user_id FROM protocol_permissions")
        }
        for row in self.db.connection.execute("SELECT * FROM protocol_permissions"):
            permissions.setdefault(row["user_id"], {})[row["protocol"]] = bool(row["enabled"])
        result: list[dict[str, Any]] = []
        users = {row["id"]: row for row in self.db.connection.execute("SELECT * FROM users")}
        for device in self.db.connection.execute("SELECT * FROM devices ORDER BY id"):
            user = users[device["user_id"]]
            active, reason = self.effective_user(user)
            active = active and bool(device["enabled"])
            if not device["enabled"]:
                reason = "设备停用"
            if active:
                item = dict(device)
                item["identity"] = f"lun:u:{user['id']}:d:{device['id']}"
                item["user_name"] = user["name"]
                item["permissions"] = permissions.get(user["id"], {})
                result.append(item)
            self.db.connection.execute(
                "INSERT INTO runtime_state(device_id,active,reason,updated_at) VALUES(?,?,?,?) "
                "ON CONFLICT(device_id) DO UPDATE SET active=excluded.active,reason=excluded.reason,updated_at=excluded.updated_at",
                (device["id"], int(active), reason, utc_now()),
            )
        self.db.connection.commit()
        return result

    @staticmethod
    def protocol_allowed(device: dict[str, Any], protocol: str) -> bool:
        return device.get("permissions", {}).get(protocol, True)

    def reconcile(self, validate: bool = True) -> dict[str, bool]:
        config = self.load_config()
        if not config.get("enabled"):
            return {"xray": False, "singbox": False}
        with FileLock(self.lock_path):
            devices = self.active_devices()
            changed = {"xray": False, "singbox": False}
            pending: list[tuple[Path, dict[str, Any], str]] = []
            xr_path = self.root / "xr.json"
            if xr_path.exists():
                original = json.loads(xr_path.read_text(encoding="utf-8"))
                updated = self._reconcile_xray(copy.deepcopy(original), devices, config)
                if updated != original:
                    pending.append((xr_path, updated, "xray"))
                    changed["xray"] = True
            sb_path = self.root / "sb.json"
            if sb_path.exists():
                original = json.loads(sb_path.read_text(encoding="utf-8"))
                updated = self._reconcile_singbox(copy.deepcopy(original), devices, config)
                if updated != original:
                    pending.append((sb_path, updated, "singbox"))
                    changed["singbox"] = True
            temporary: list[tuple[Path, Path, str]] = []
            try:
                for target, payload, core in pending:
                    temp = target.with_name(f".{target.stem}.multiuser.{os.getpid()}{target.suffix}")
                    atomic_write(temp, json.dumps(payload, ensure_ascii=False, indent=2) + "\n")
                    temporary.append((target, temp, core))
                if validate:
                    for _, temp, core in temporary:
                        self._validate_core(core, temp)
                for target, temp, _ in temporary:
                    shutil.copy2(target, self.generated / f"previous-{target.name}")
                    os.replace(temp, target)
            finally:
                for _, temp, _ in temporary:
                    temp.unlink(missing_ok=True)
            self.render_all_subscriptions()
            self.db.audit("config.reconcile", "cores", json.dumps(changed))
            self.db.connection.commit()
            return changed

    def _reconcile_xray(self, data: dict[str, Any], devices: list[dict[str, Any]], config: dict[str, Any]) -> dict[str, Any]:
        for inbound in data.get("inbounds", []):
            tag = inbound.get("tag", "")
            protocol_key = XRAY_TAG_PROTOCOL.get(tag)
            if not protocol_key:
                continue
            selected = [d for d in devices if self.protocol_allowed(d, protocol_key)]
            settings = inbound.setdefault("settings", {})
            protocol = inbound.get("protocol")
            if protocol in {"vless", "vmess"}:
                templates = settings.get("clients") or [{}]
                template = copy.deepcopy(templates[0])
                clients = []
                for device in selected:
                    client = copy.deepcopy(template)
                    client["id"] = device["uuid"]
                    client["email"] = device["identity"]
                    client["level"] = 0
                    clients.append(client)
                settings["clients"] = clients
            elif protocol == "socks":
                settings["accounts"] = [
                    {"user": d["uuid"], "pass": d["password"]} for d in selected
                ]
        data["stats"] = {}
        data["api"] = {
            "tag": "lun-api",
            "listen": config.get("xray_api", "127.0.0.1:10085"),
            "services": ["HandlerService", "StatsService"],
        }
        policy = data.setdefault("policy", {})
        level = policy.setdefault("levels", {}).setdefault("0", {})
        level.update({"statsUserUplink": True, "statsUserDownlink": True, "statsUserOnline": True})
        outbounds = data.setdefault("outbounds", [])
        outbounds[:] = [item for item in outbounds if item.get("tag") != "lun-blocked"]
        outbounds.append({"tag": "lun-blocked", "protocol": "blackhole", "settings": {}})
        routing = data.setdefault("routing", {})
        rules = routing.setdefault("rules", [])
        rules[:] = [rule for rule in rules if rule.get("outboundTag") != "lun-blocked"]
        rules[0:0] = [
            {"type": "field", "ip": PRIVATE_CIDRS, "outboundTag": "lun-blocked"},
            {"type": "field", "domain": [f"full:{d}" for d in BLOCKED_METADATA_DOMAINS], "outboundTag": "lun-blocked"},
            {"type": "field", "network": "tcp", "port": "25", "outboundTag": "lun-blocked"},
        ]
        return data

    def _reconcile_singbox(self, data: dict[str, Any], devices: list[dict[str, Any]], config: dict[str, Any]) -> dict[str, Any]:
        inbounds = data.setdefault("inbounds", [])
        inbounds[:] = [item for item in inbounds if item.get("tag") != "ss-2022-mu"]
        ss_template: dict[str, Any] | None = None
        for inbound in inbounds:
            tag = inbound.get("tag", "")
            key = SINGBOX_TAG_PROTOCOL.get(tag)
            if not key:
                continue
            if tag == "ss-2022":
                ss_template = inbound
                continue
            selected = [d for d in devices if self.protocol_allowed(d, key)]
            inbound_type = inbound.get("type")
            users: list[dict[str, Any]] = []
            for device in selected:
                identity = device["identity"]
                if inbound_type == "naive":
                    users.append({"username": device["uuid"], "password": device["password"]})
                elif inbound_type == "hysteria2":
                    users.append({"name": identity, "password": device["password"]})
                elif inbound_type == "tuic":
                    users.append({"name": identity, "uuid": device["uuid"], "password": device["password"]})
                elif inbound_type == "anytls":
                    users.append({"name": identity, "password": device["password"]})
                elif inbound_type == "vmess":
                    users.append({"name": identity, "uuid": device["uuid"], "alterId": 0})
                elif inbound_type == "socks":
                    users.append({"username": device["uuid"], "password": device["password"]})
            inbound["users"] = users
        ss_port = int(config.get("ss_port") or 0)
        if ss_template and ss_port:
            selected = [d for d in devices if self.protocol_allowed(d, "ss")]
            multi = copy.deepcopy(ss_template)
            multi["tag"] = "ss-2022-mu"
            multi["listen_port"] = ss_port
            multi["password"] = config["ss_server_password"]
            multi["users"] = [{"name": d["identity"], "password": d["ss_password"]} for d in selected]
            inbounds.append(multi)
        route = data.setdefault("route", {})
        rules = route.setdefault("rules", [])
        rules[:] = [rule for rule in rules if not self._is_singbox_guard_rule(rule)]
        rules[0:0] = [
            {"ip_is_private": True, "action": "reject"},
            {"domain": BLOCKED_METADATA_DOMAINS, "action": "reject"},
            {"network": "tcp", "port": 25, "action": "reject"},
        ]
        version_output = self._run([str(self.root / "sing-box"), "version"], check=False).stdout
        if "with_v2ray_api" in version_output:
            experimental = data.setdefault("experimental", {})
            stat_users: list[str] = []
            for device in devices:
                stat_users.extend((device["identity"], device["uuid"]))
            experimental["v2ray_api"] = {
                "listen": config.get("singbox_api", "127.0.0.1:10086"),
                "stats": {"enabled": True, "users": sorted(set(stat_users))},
            }
        return data

    @staticmethod
    def _is_singbox_guard_rule(rule: dict[str, Any]) -> bool:
        if rule.get("action") != "reject":
            return False
        if rule.get("ip_is_private") is True and len(rule) == 2:
            return True
        if rule.get("domain") == BLOCKED_METADATA_DOMAINS and len(rule) == 2:
            return True
        return rule.get("network") == "tcp" and rule.get("port") == 25 and len(rule) == 3

    def _validate_core(self, core: str, path: Path) -> None:
        if core == "xray":
            binary = self.root / "xray"
            command = [str(binary), "run", "-test", "-c", str(path)]
        else:
            binary = self.root / "sing-box"
            command = [str(binary), "check", "-c", str(path)]
        if not binary.exists():
            raise AgentError(f"缺少 {core} 内核，无法校验配置")
        result = self._run(command, check=False)
        if result.returncode:
            raise AgentError(f"{core} 配置校验失败：{result.stderr.strip() or result.stdout.strip()}")

    @staticmethod
    def _run(command: list[str], check: bool = True, timeout: int = 15) -> subprocess.CompletedProcess[str]:
        try:
            return subprocess.run(command, text=True, capture_output=True, check=check, timeout=timeout)
        except (OSError, subprocess.SubprocessError) as exc:
            if check:
                raise AgentError(str(exc)) from exc
            return subprocess.CompletedProcess(command, 127, "", str(exc))

    def restart_cores(self, changed: dict[str, bool] | None = None) -> None:
        changed = changed or {"xray": (self.root / "xr.json").exists(), "singbox": (self.root / "sb.json").exists()}
        if Path("/run/systemd/system").exists() and shutil.which("systemctl"):
            if changed.get("xray"):
                self._run(["systemctl", "reset-failed", "xr"], check=False)
                self._run(["systemctl", "restart", "xr"])
            if changed.get("singbox"):
                self._run(["systemctl", "reset-failed", "sb"], check=False)
                self._run(["systemctl", "restart", "sb"])
            return
        if shutil.which("rc-service"):
            if changed.get("xray"):
                self._run(["rc-service", "xray", "restart"])
            if changed.get("singbox"):
                self._run(["rc-service", "sing-box", "restart"])
            return
        raise AgentError("多用户模块要求 systemd 或 OpenRC；未执行不可靠的无 init 重启")

    def apply(self) -> dict[str, bool]:
        changed = self.reconcile(validate=True)
        try:
            self.restart_cores(changed)
        except AgentError as exc:
            restored: dict[str, bool] = {"xray": False, "singbox": False}
            for core, filename in (("xray", "xr.json"), ("singbox", "sb.json")):
                previous = self.generated / f"previous-{filename}"
                target = self.root / filename
                if changed.get(core) and previous.exists():
                    shutil.copy2(previous, target)
                    restored[core] = True
            rollback_error = ""
            try:
                self.restart_cores(restored)
            except AgentError as rollback_exc:
                rollback_error = f"；回滚配置已写回，但核心重启仍失败：{rollback_exc}"
            raise AgentError(f"核心重启失败，已恢复应用前配置：{exc}{rollback_error}") from exc
        return changed

    def _protocol_from_name(self, name: str, scheme: str = "") -> str:
        lowered = name.lower()
        if "shadowsocks" in lowered or scheme == "ss": return "ss"
        if "anyreality" in lowered: return "ar"
        if "anytls" in lowered or scheme == "anytls": return "an"
        if "hysteria" in lowered or scheme in {"hy2", "hysteria2"}: return "hy"
        if "tuic" in lowered or scheme == "tuic": return "tu"
        if "naive" in lowered or scheme.startswith("naive+") or scheme in {"http2", "http3"}: return "nv"
        if "socks" in lowered or scheme.startswith("socks"): return "so"
        if "vmess" in lowered or "vm-" in lowered or scheme == "vmess": return "vm"
        if "tls-udp" in lowered: return "xu"
        if "tls-tcp" in lowered or "cdn-tcp" in lowered or "cdn-udp-exp" in lowered: return "xc"
        if "xhttp-reality" in lowered: return "xh"
        if "xhttp" in lowered: return "vx"
        if "ws" in lowered: return "vw"
        if "reality" in lowered: return "vl"
        return ""

    def _legacy_placeholders(self, text: str, legacy_uuid: str) -> tuple[str, dict[str, str]]:
        placeholders: dict[str, str] = {}
        for suffix in ("xh", "vx", "xu", "xc", "vw", "vm"):
            original = f"{legacy_uuid}-{suffix}"
            marker = f"__LUN_SERVER_PATH_{suffix.upper()}__"
            if original in text:
                text = text.replace(original, marker)
                placeholders[marker] = original
        return text, placeholders

    @staticmethod
    def _restore_placeholders(text: str, placeholders: dict[str, str]) -> str:
        for marker, original in placeholders.items():
            text = text.replace(marker, original)
        return text

    def render_generic(self, source: str, device: sqlite3.Row, permissions: dict[str, bool], config: dict[str, Any]) -> str:
        lines: list[str] = []
        legacy_uuid = config["legacy_uuid"]
        for raw in source.splitlines():
            line = raw.strip()
            if not line:
                continue
            scheme = line.split(":", 1)[0].lower()
            name = urllib.parse.unquote(line.rsplit("#", 1)[-1]) if "#" in line else line
            protocol = self._protocol_from_name(name, scheme)
            if protocol and not permissions.get(protocol, True):
                continue
            try:
                if scheme == "vmess":
                    encoded = line.split("://", 1)[1]
                    payload = json.loads(base64.urlsafe_b64decode(encoded + "=" * (-len(encoded) % 4)).decode())
                    payload["id"] = device["uuid"]
                    line = "vmess://" + base64.b64encode(json.dumps(payload, ensure_ascii=False).encode()).decode()
                elif scheme == "ss":
                    line = self._render_ss_link(line, device, config)
                else:
                    protected, placeholders = self._legacy_placeholders(line, legacy_uuid)
                    protected = protected.replace(legacy_uuid, device["uuid"])
                    if scheme in {"naive+https", "naive+quic", "http2", "http3", "tuic"}:
                        parsed = urllib.parse.urlsplit(protected)
                        username = device["uuid"]
                        password = device["password"]
                        host = parsed.hostname or ""
                        host = f"[{host}]" if ":" in host and not host.startswith("[") else host
                        netloc = f"{urllib.parse.quote(username)}:{urllib.parse.quote(password)}@{host}"
                        if parsed.port:
                            netloc += f":{parsed.port}"
                        protected = urllib.parse.urlunsplit((parsed.scheme, netloc, parsed.path, parsed.query, parsed.fragment))
                    elif scheme in {"hy2", "hysteria2", "anytls"}:
                        parsed = urllib.parse.urlsplit(protected)
                        host = parsed.hostname or ""
                        host = f"[{host}]" if ":" in host and not host.startswith("[") else host
                        netloc = f"{urllib.parse.quote(device['password'])}@{host}"
                        if parsed.port:
                            netloc += f":{parsed.port}"
                        protected = urllib.parse.urlunsplit((parsed.scheme, netloc, parsed.path, parsed.query, parsed.fragment))
                    line = self._restore_placeholders(protected, placeholders)
            except (ValueError, json.JSONDecodeError, UnicodeError):
                protected, placeholders = self._legacy_placeholders(line, legacy_uuid)
                line = self._restore_placeholders(protected.replace(legacy_uuid, device["uuid"]), placeholders)
            lines.append(line)
        return "\n".join(lines) + ("\n" if lines else "")

    def _render_ss_link(self, line: str, device: sqlite3.Row, config: dict[str, Any]) -> str:
        fragment = line.split("#", 1)[1] if "#" in line else ""
        encoded = line.split("://", 1)[1].split("#", 1)[0]
        decoded = base64.urlsafe_b64decode(encoded + "=" * (-len(encoded) % 4)).decode()
        method, rest = decoded.split(":", 1)
        _, endpoint = rest.rsplit("@", 1)
        host, _ = endpoint.rsplit(":", 1)
        password = f"{config['ss_server_password']}:{device['ss_password']}"
        payload = f"{method}:{password}@{host}:{config['ss_public_port']}"
        return "ss://" + base64.b64encode(payload.encode()).decode() + (f"#{fragment}" if fragment else "")

    def render_singbox(self, source: str, device: sqlite3.Row, permissions: dict[str, bool], config: dict[str, Any]) -> str:
        data = json.loads(source)
        removed: set[str] = set()
        outbounds = []
        for outbound in data.get("outbounds", []):
            kind = outbound.get("type", "")
            tag = outbound.get("tag", "")
            protocol = self._protocol_from_name(tag, kind)
            if protocol and protocol in PROTOCOLS and not permissions.get(protocol, True):
                removed.add(tag)
                continue
            if kind in {"vless", "vmess"}:
                outbound["uuid"] = device["uuid"]
            elif kind in {"hysteria2", "anytls"}:
                outbound["password"] = device["password"]
            elif kind == "tuic":
                outbound["uuid"] = device["uuid"]
                outbound["password"] = device["password"]
            elif kind in {"naive", "socks"}:
                outbound["username"] = device["uuid"]
                outbound["password"] = device["password"]
            elif kind == "shadowsocks":
                outbound["password"] = f"{config['ss_server_password']}:{device['ss_password']}"
                if config.get("ss_public_port"):
                    outbound["server_port"] = config["ss_public_port"]
            outbounds.append(outbound)
        for outbound in outbounds:
            if isinstance(outbound.get("outbounds"), list):
                outbound["outbounds"] = [tag for tag in outbound["outbounds"] if tag not in removed]
        data["outbounds"] = outbounds
        return json.dumps(data, ensure_ascii=False, indent=2) + "\n"

    def render_clash(self, source: str, device: sqlite3.Row, permissions: dict[str, bool], config: dict[str, Any]) -> str:
        protected, placeholders = self._legacy_placeholders(source, config["legacy_uuid"])
        text = protected.replace(config["legacy_uuid"], device["uuid"])
        lines = text.splitlines()
        try:
            start = lines.index("proxies:") + 1
            end = lines.index("proxy-groups:")
        except ValueError:
            return self._restore_placeholders(text, placeholders) + "\n"
        blocks: list[list[str]] = []
        current: list[str] = []
        for line in lines[start:end]:
            if line.startswith("- name:") and current:
                blocks.append(current)
                current = []
            current.append(line)
        if current:
            blocks.append(current)
        kept: list[str] = []
        removed_names: set[str] = set()
        for block in blocks:
            joined = "\n".join(block)
            match = re.search(r"^- name:\s*[\"']?(.+?)[\"']?\s*$", joined, re.M)
            name = match.group(1) if match else joined
            protocol = self._protocol_from_name(name)
            if protocol and not permissions.get(protocol, True):
                removed_names.add(name)
                continue
            if protocol == "ss":
                block = [
                    re.sub(r"^(\s*port:)\s*\d+", rf"\1 {config['ss_public_port']}", item)
                    if re.match(r"\s*port:", item) else item for item in block
                ]
                block = [
                    re.sub(r"^(\s*password:)\s*.*", rf'\1 "{config["ss_server_password"]}:{device["ss_password"]}"', item)
                    if re.match(r"\s*password:", item) else item for item in block
                ]
            elif protocol in {"an", "ar", "hy"}:
                block = [re.sub(r"^(\s*password:)\s*.*", rf"\1 {device['password']}", item) if re.match(r"\s*password:", item) else item for item in block]
            elif protocol in {"tu", "nv", "so"}:
                block = [re.sub(r"^(\s*(?:password|username):)\s*.*", lambda m: f"{m.group(1)} {device['password'] if 'password' in m.group(1) else device['uuid']}", item) if re.match(r"\s*(?:password|username):", item) else item for item in block]
            kept.extend(block)
        tail = []
        for line in lines[end:]:
            stripped = line.strip().lstrip("- ").strip('"\'')
            if stripped in removed_names:
                continue
            tail.append(line)
        output = "\n".join(lines[:start] + kept + tail) + "\n"
        return self._restore_placeholders(output, placeholders)

    def device_permissions(self, user_id: int) -> dict[str, bool]:
        values = {protocol: True for protocol in PROTOCOLS}
        for row in self.db.connection.execute(
            "SELECT protocol,enabled FROM protocol_permissions WHERE user_id=?", (user_id,)
        ):
            values[row["protocol"]] = bool(row["enabled"])
        return values

    def render_all_subscriptions(self) -> None:
        if not self.config_path.exists():
            return
        config = self.load_config()
        self.generated.mkdir(parents=True, exist_ok=True)
        sources = {
            "jhsub.txt": self.root / "jhsub.txt",
            "clmi.yaml": self.root / "clmi.yaml",
            "sbox.json": self.root / "sbox.json",
        }
        for device in self.db.connection.execute("SELECT * FROM devices"):
            target = self.generated / device["token"]
            target.mkdir(parents=True, exist_ok=True)
            permissions = self.device_permissions(device["user_id"])
            for name, source_path in sources.items():
                if not source_path.exists():
                    continue
                source = source_path.read_text(encoding="utf-8")
                if device["legacy"] and device["token"] == config.get("legacy_token"):
                    rendered = source
                elif name == "jhsub.txt":
                    rendered = self.render_generic(source, device, permissions, config)
                elif name == "sbox.json":
                    rendered = self.render_singbox(source, device, permissions, config)
                else:
                    rendered = self.render_clash(source, device, permissions, config)
                atomic_write(target / name, rendered, 0o644)

    def subscription_info(self, device: sqlite3.Row) -> dict[str, int]:
        user = self.db.connection.execute("SELECT * FROM users WHERE id=?", (device["user_id"],)).fetchone()
        lifetime, monthly = self.usage_for_user(user["id"])
        total = user["lifetime_quota"] or user["monthly_quota"] or 0
        used = lifetime if user["lifetime_quota"] else monthly
        return {"upload": used // 2, "download": used - used // 2, "total": total, "expire": user["expires_at"] or 0}

    def find_device_by_token(self, token: str) -> tuple[sqlite3.Row | None, bool, str]:
        device = self.db.connection.execute("SELECT * FROM devices WHERE token=?", (token,)).fetchone()
        if not device:
            return None, False, "token 不存在"
        user = self.db.connection.execute("SELECT * FROM users WHERE id=?", (device["user_id"],)).fetchone()
        active, reason = self.effective_user(user)
        if not device["enabled"]:
            return device, False, "设备停用"
        return device, active, reason

    def sample_core_stats(self, core: str, server: str) -> int:
        if core == "singbox":
            helper = self.module / "lun-sb-stats"
            if not helper.exists():
                return 0
            command = [str(helper), f"--server={server}", "--pattern=user>>>", "--reset"]
        else:
            xray = self.root / "xray"
            if not xray.exists():
                return 0
            command = [str(xray), "api", "statsquery", f"--server={server}", "-pattern", "user>>>", "-reset"]
        result = self._run(command, check=False)
        if result.returncode:
            return 0
        try:
            payload = json.loads(result.stdout)
            stats = payload.get("stat", payload.get("stats", []))
        except json.JSONDecodeError:
            stats = [
                {"name": name, "value": value}
                for name, value in re.findall(r'name:\s*"([^"]+)"[\s\S]*?value:\s*([0-9]+)', result.stdout)
            ]
        identities: dict[str, sqlite3.Row] = {}
        for row in self.db.connection.execute("SELECT * FROM devices"):
            identities[f"lun:u:{row['user_id']}:d:{row['id']}"] = row
            # Authenticated SOCKS implementations commonly expose the username
            # instead of an email/name in their user counter.
            identities[row["uuid"]] = row
        totals: dict[tuple[int, str], int] = {}
        for stat in stats:
            name = str(stat.get("name", ""))
            match = re.fullmatch(r"user>>>(.+)>>>traffic>>>(uplink|downlink)", name)
            if not match or match.group(1) not in identities:
                continue
            value = int(stat.get("value", 0))
            key = (identities[match.group(1)]["id"], match.group(2))
            totals[key] = totals.get(key, 0) + max(0, value)
        now = utc_now()
        with self.db.connection:
            for (device_id, direction), value in totals.items():
                user = self.db.connection.execute(
                    "SELECT u.reset_day FROM users u JOIN devices d ON d.user_id=u.id WHERE d.id=?", (device_id,)
                ).fetchone()
                period = self.month_period(user["reset_day"])
                self.db.connection.execute(
                    "INSERT INTO usage_totals(device_id,core,uplink,downlink,month_uplink,month_downlink,period_start,updated_at) "
                    "VALUES(?,?,?,?,?,?,?,?) ON CONFLICT(device_id,core) DO UPDATE SET "
                    f"{direction}={direction}+excluded.{direction},month_{direction}=CASE WHEN period_start=excluded.period_start "
                    f"THEN month_{direction}+excluded.month_{direction} ELSE excluded.month_{direction} END,"
                    "period_start=excluded.period_start,updated_at=excluded.updated_at",
                    (device_id, core, value if direction == "uplink" else 0, value if direction == "downlink" else 0,
                     value if direction == "uplink" else 0, value if direction == "downlink" else 0, period, now),
                )
        return sum(totals.values())

    def collect_stats(self) -> int:
        config = self.load_config()
        total = self.sample_core_stats("xray", config.get("xray_api", "127.0.0.1:10085"))
        sb_version = self._run([str(self.root / "sing-box"), "version"], check=False).stdout
        if "with_v2ray_api" in sb_version and (self.module / "lun-sb-stats").exists():
            total += self.sample_core_stats("singbox", config.get("singbox_api", "127.0.0.1:10086"))
        return total

    def revoke_xray_devices(self, device_ids: Iterable[int]) -> bool:
        ids = list(device_ids)
        if not ids or not (self.root / "xr.json").exists():
            return True
        placeholders = ",".join("?" for _ in ids)
        rows = self.db.connection.execute(
            f"SELECT id,user_id FROM devices WHERE id IN ({placeholders})", ids
        ).fetchall()
        identities = [f"lun:u:{row['user_id']}:d:{row['id']}" for row in rows]
        if not identities:
            return True
        try:
            data = json.loads((self.root / "xr.json").read_text(encoding="utf-8"))
        except (OSError, json.JSONDecodeError):
            return False
        tags = [
            inbound.get("tag") for inbound in data.get("inbounds", [])
            if inbound.get("protocol") in {"vless", "vmess"} and inbound.get("tag")
        ]
        server = self.load_config().get("xray_api", "127.0.0.1:10085")
        binary = str(self.root / "xray")
        success = True
        for tag in tags:
            result = self._run(
                [binary, "api", "rmu", f"--server={server}", f"-tag={tag}", *identities],
                check=False,
            )
            # A user may be absent from a protocol because of a per-user permission.
            # Treat only transport/API failures as fatal; persisted config remains the fallback.
            if result.returncode and any(word in (result.stderr + result.stdout).lower() for word in ("connection", "timeout", "refused")):
                success = False
        return success

    def xray_has_socks(self) -> bool:
        try:
            data = json.loads((self.root / "xr.json").read_text(encoding="utf-8"))
        except (OSError, json.JSONDecodeError):
            return False
        return any(item.get("protocol") == "socks" for item in data.get("inbounds", []))

    def maintenance_once(self) -> dict[str, Any]:
        before = {row["device_id"]: bool(row["active"]) for row in self.db.connection.execute("SELECT * FROM runtime_state")}
        sampled = self.collect_stats()
        reset = self.reset_month_periods()
        active = self.active_devices()
        active_ids = {item["id"] for item in active}
        after = {row["id"]: row["id"] in active_ids for row in self.db.connection.execute("SELECT id FROM devices")}
        transitions = [device_id for device_id, state in after.items() if before.get(device_id) != state]
        revoked = [device_id for device_id in transitions if before.get(device_id) and not after[device_id]]
        restored = [device_id for device_id in transitions if after[device_id]]
        if transitions or reset:
            dynamic_revoke_ok = self.revoke_xray_devices(revoked)
            changed = self.reconcile(validate=True)
            restart = {
                "xray": bool(changed.get("xray") and (restored or self.xray_has_socks() or not dynamic_revoke_ok)),
                "singbox": bool(changed.get("singbox")),
            }
            if restart["xray"] or restart["singbox"]:
                self.restart_cores(restart)
        return {"sampled": sampled, "transitions": transitions, "revoked": revoked,
                "restored": restored, "monthly_reset": reset}

    def backup_database(self) -> Path:
        self.backups.mkdir(parents=True, exist_ok=True)
        target = self.backups / f"db-{dt.datetime.now(dt.timezone.utc).strftime('%Y%m%d-%H%M%S-%f')}.sqlite3"
        destination = sqlite3.connect(target)
        try:
            self.db.connection.backup(destination)
        finally:
            destination.close()
        os.chmod(target, 0o600)
        backups = sorted(self.backups.glob("db-*.sqlite3"), reverse=True)
        for old in backups[7:]:
            old.unlink(missing_ok=True)
        return target

    def restore_database(self, source_path: str) -> None:
        source = Path(source_path).expanduser().resolve()
        try:
            source.relative_to(self.backups.resolve())
        except ValueError as exc:
            raise AgentError("只允许恢复多用户模块备份目录中的数据库") from exc
        if not source.is_file():
            raise AgentError("数据库备份不存在")
        backup = sqlite3.connect(source)
        try:
            if backup.execute("PRAGMA integrity_check").fetchone()[0] != "ok":
                raise AgentError("数据库备份完整性检查失败")
            with FileLock(self.lock_path):
                backup.backup(self.db.connection)
                self.db.audit("database.restore", source.name)
                self.db.connection.commit()
        finally:
            backup.close()

    def status_rows(self) -> list[dict[str, Any]]:
        rows = []
        for user in self.db.connection.execute("SELECT * FROM users ORDER BY id"):
            active, reason = self.effective_user(user)
            lifetime, monthly = self.usage_for_user(user["id"])
            devices = self.db.connection.execute("SELECT COUNT(*) FROM devices WHERE user_id=?", (user["id"],)).fetchone()[0]
            rows.append({
                "id": user["id"], "name": user["name"], "active": active, "reason": reason,
                "devices": devices, "max_devices": user["max_devices"], "lifetime": lifetime,
                "monthly": monthly, "lifetime_quota": user["lifetime_quota"],
                "monthly_quota": user["monthly_quota"], "expires_at": user["expires_at"],
            })
        return rows

    def doctor(self) -> dict[str, Any]:
        config = self.load_config()
        checks: dict[str, Any] = {
            "database": self.db.connection.execute("PRAGMA integrity_check").fetchone()[0],
            "enabled": bool(config.get("enabled")),
            "xray_config": (self.root / "xr.json").exists(),
            "singbox_config": (self.root / "sb.json").exists(),
            "subscription_files": all((self.root / name).exists() for name in ("jhsub.txt", "clmi.yaml", "sbox.json")),
            "scheme": config.get("scheme"),
            "port": config.get("port"),
            "legacy_http_port": config.get("legacy_http_port", 0),
        }
        if (self.root / "xray").exists():
            checks["xray_validate"] = self._run([str(self.root / "xray"), "run", "-test", "-c", str(self.root / "xr.json")], check=False).returncode == 0
        if (self.root / "sing-box").exists() and (self.root / "sb.json").exists():
            checks["singbox_validate"] = self._run([str(self.root / "sing-box"), "check", "-c", str(self.root / "sb.json")], check=False).returncode == 0
            checks["singbox_v2ray_api"] = "with_v2ray_api" in self._run([str(self.root / "sing-box"), "version"], check=False).stdout
            checks["singbox_stats_helper"] = (self.module / "lun-sb-stats").exists()
        return checks


class SubscriptionHandler(http.server.BaseHTTPRequestHandler):
    server_version = "FHLUN-Subscription/1"

    def do_GET(self) -> None:  # noqa: N802
        self._serve_subscription(send_body=True)

    def do_HEAD(self) -> None:  # noqa: N802
        self._serve_subscription(send_body=False)

    def _serve_subscription(self, send_body: bool) -> None:
        agent: Agent = self.server.agent  # type: ignore[attr-defined]
        parsed = urllib.parse.urlsplit(self.path)
        parts = [urllib.parse.unquote(item) for item in parsed.path.split("/") if item]
        if len(parts) != 2 or parts[1] not in {"jhsub.txt", "clmi.yaml", "sbox.json"}:
            self.send_error(404)
            return
        token, filename = parts
        if getattr(self.server, "legacy_only", False):  # type: ignore[attr-defined]
            config = agent.load_config()
            if token != config.get("legacy_token"):
                self.send_error(404)
                return
        device, active, reason = agent.find_device_by_token(token)
        if not device:
            self.send_error(404)
            return
        if not active:
            self.send_error(403, "Subscription disabled")
            return
        target = agent.generated / token / filename
        if not target.exists():
            agent.render_all_subscriptions()
        if not target.exists():
            self.send_error(404)
            return
        payload = target.read_bytes()
        info = agent.subscription_info(device)
        content_type = {"jhsub.txt": "text/plain", "clmi.yaml": "text/yaml", "sbox.json": "application/json"}[filename]
        self.send_response(200)
        self.send_header("Content-Type", f"{content_type}; charset=utf-8")
        self.send_header("Content-Length", str(len(payload)))
        self.send_header("Cache-Control", "no-store")
        self.send_header("Subscription-Userinfo", "; ".join(f"{key}={value}" for key, value in info.items()))
        self.end_headers()
        if send_body:
            self.wfile.write(payload)

    def log_message(self, fmt: str, *args: Any) -> None:
        # Never log subscription tokens or request paths.
        sys.stderr.write(f"subscription {self.client_address[0]} {args[1] if len(args) > 1 else ''}\n")


class DualStackServer(http.server.ThreadingHTTPServer):
    address_family = socket.AF_INET6
    daemon_threads = True
    allow_reuse_address = True

    def server_bind(self) -> None:
        with contextlib.suppress(OSError):
            self.socket.setsockopt(socket.IPPROTO_IPV6, socket.IPV6_V6ONLY, 0)
        super().server_bind()


def serve(agent: Agent) -> None:
    config = agent.load_config()
    if not config.get("enabled"):
        raise AgentError("多用户模块已停用")
    agent.reconcile(validate=False)
    bind = config.get("bind", "::")
    server_class: type[http.server.ThreadingHTTPServer] = DualStackServer if ":" in bind else http.server.ThreadingHTTPServer

    def make_server(port: int, use_tls: bool, legacy_only: bool) -> http.server.ThreadingHTTPServer:
        current = server_class((bind, port), SubscriptionHandler)
        current.agent = agent  # type: ignore[attr-defined]
        current.legacy_only = legacy_only  # type: ignore[attr-defined]
        if use_tls:
            context = ssl.SSLContext(ssl.PROTOCOL_TLS_SERVER)
            context.minimum_version = ssl.TLSVersion.TLSv1_2
            context.load_cert_chain(config["certificate"], config["private_key"])
            current.socket = context.wrap_socket(current.socket, server_side=True)
        return current

    server = make_server(int(config["port"]), config.get("scheme") == "https", False)
    legacy_server: http.server.ThreadingHTTPServer | None = None
    legacy_port = int(config.get("legacy_http_port") or 0)
    if legacy_port and legacy_port != int(config["port"]):
        legacy_server = make_server(legacy_port, False, True)
        threading.Thread(target=legacy_server.serve_forever, kwargs={"poll_interval": 0.5}, daemon=True).start()
    stopping = threading.Event()

    def stop(*_: Any) -> None:
        stopping.set()
        threading.Thread(target=server.shutdown, daemon=True).start()
        if legacy_server:
            threading.Thread(target=legacy_server.shutdown, daemon=True).start()

    signal.signal(signal.SIGTERM, stop)
    signal.signal(signal.SIGINT, stop)

    def maintenance_loop() -> None:
        interval = int(config.get("poll_interval", 30))
        while not stopping.wait(interval):
            try:
                agent.maintenance_once()
            except Exception as exc:  # service must keep subscriptions alive on stats failure
                sys.stderr.write(f"maintenance failed: {exc}\n")

    threading.Thread(target=maintenance_loop, name="maintenance", daemon=True).start()
    try:
        server.serve_forever(poll_interval=0.5)
    finally:
        server.server_close()
        if legacy_server:
            legacy_server.server_close()


def print_device(device: sqlite3.Row, config: dict[str, Any]) -> None:
    host = config.get("public_host") or "SERVER"
    port = config.get("public_port") or config.get("port")
    scheme = config.get("scheme", "http")
    print(f"设备 ID：{device['id']}")
    print(f"设备名称：{device['name']}")
    print(f"UUID：{device['uuid']}")
    print(f"通用密码：{device['password']}")
    print(f"SS-2022 用户密钥：{device['ss_password']}")
    print(f"订阅 token：{device['token']}")
    for filename, label in (("clmi.yaml", "Clash/Mihomo"), ("sbox.json", "Sing-box"), ("jhsub.txt", "聚合")):
        print(f"{label}：{scheme}://{host}:{port}/{device['token']}/{filename}")


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(prog="lun-agent")
    parser.add_argument("--root", default=os.path.expanduser("~/lun"))
    parser.add_argument("--json", action="store_true")
    sub = parser.add_subparsers(dest="command", required=True)

    init = sub.add_parser("init")
    init.add_argument("--legacy-uuid")
    init.add_argument("--legacy-token")
    init.add_argument("--bind", default="::")
    init.add_argument("--port", type=int, required=True)
    init.add_argument("--public-port", type=int, default=0)
    init.add_argument("--legacy-http-port", type=int, default=0)
    init.add_argument("--legacy-http-public-port", type=int, default=0)
    init.add_argument("--scheme", choices=("http", "https"), required=True)
    init.add_argument("--public-host", required=True)
    init.add_argument("--certificate")
    init.add_argument("--private-key")
    init.add_argument("--xray-api", default="127.0.0.1:10085")
    init.add_argument("--singbox-api", default="127.0.0.1:10086")
    init.add_argument("--poll-interval", type=int, default=30)
    init.add_argument("--ss-port", type=int, default=0)
    init.add_argument("--ss-public-port", type=int, default=0)
    init.add_argument("--ss-server-password")

    add = sub.add_parser("add-user")
    add.add_argument("--name", required=True)
    add.add_argument("--lifetime-quota", default="0")
    add.add_argument("--monthly-quota", default="0")
    add.add_argument("--reset-day", type=int, choices=range(1, 29), default=1)
    add.add_argument("--expires", default="never")
    add.add_argument("--max-devices", type=int, choices=range(1, 65), default=3)
    add.add_argument("--device-name", default="device-1")

    add_device_parser = sub.add_parser("add-device")
    add_device_parser.add_argument("--user-id", type=int, required=True)
    add_device_parser.add_argument("--name", required=True)

    update_device_parser = sub.add_parser("update-device")
    update_device_parser.add_argument("--device-id", type=int, required=True)
    update_device_parser.add_argument("--name")
    device_state = update_device_parser.add_mutually_exclusive_group()
    device_state.add_argument("--enable", dest="enabled", action="store_true")
    device_state.add_argument("--disable", dest="enabled", action="store_false")
    update_device_parser.set_defaults(enabled=None)

    rotate_device_parser = sub.add_parser("rotate-device")
    rotate_device_parser.add_argument("--device-id", type=int, required=True)
    rotate_device_parser.add_argument("--confirm", required=True)

    delete_device_parser = sub.add_parser("delete-device")
    delete_device_parser.add_argument("--device-id", type=int, required=True)
    delete_device_parser.add_argument("--confirm", required=True)

    update = sub.add_parser("update-user")
    update.add_argument("--user-id", type=int, required=True)
    update.add_argument("--lifetime-quota")
    update.add_argument("--monthly-quota")
    update.add_argument("--reset-day", type=int, choices=range(1, 29))
    update.add_argument("--expires")
    update.add_argument("--max-devices", type=int, choices=range(1, 65))
    state = update.add_mutually_exclusive_group()
    state.add_argument("--enable", dest="enabled", action="store_true")
    state.add_argument("--disable", dest="enabled", action="store_false")
    update.set_defaults(enabled=None)

    protocol = sub.add_parser("set-protocol")
    protocol.add_argument("--user-id", type=int, required=True)
    protocol.add_argument("--protocol", choices=PROTOCOLS, required=True)
    protocol.add_argument("--enabled", choices=("yes", "no"), required=True)

    delete = sub.add_parser("delete-user")
    delete.add_argument("--user-id", type=int, required=True)
    delete.add_argument("--confirm", required=True)

    show = sub.add_parser("show-user")
    show.add_argument("--user-id", type=int, required=True)
    show_sub = sub.add_parser("show-subscription")
    show_sub.add_argument("--device-id", type=int, required=True)
    sub.add_parser("list-users")
    sub.add_parser("status")
    sub.add_parser("usage")
    sub.add_parser("reconcile")
    sub.add_parser("apply")
    sub.add_parser("maintenance")
    sub.add_parser("backup")
    restore = sub.add_parser("restore-database")
    restore.add_argument("--path", required=True)
    sub.add_parser("doctor")
    sub.add_parser("serve")
    enable = sub.add_parser("set-module")
    enable.add_argument("--enabled", choices=("yes", "no"), required=True)
    return parser


def main(argv: list[str] | None = None) -> int:
    parser = build_parser()
    args = parser.parse_args(argv)
    agent = Agent(Path(args.root))
    try:
        result: Any = None
        if args.command == "init":
            result = agent.initialize(args)
            print("多用户模块初始化完成。")
        elif args.command == "add-user":
            device = agent.add_user(args)
            result = dict(device)
            print_device(device, agent.load_config())
        elif args.command == "add-device":
            device = agent.add_device(args.user_id, args.name)
            result = dict(device)
            print_device(device, agent.load_config())
        elif args.command == "update-device":
            device = agent.update_device(args.device_id, args.name, args.enabled)
            result = dict(device)
            print("设备信息已更新。")
        elif args.command == "rotate-device":
            device = agent.rotate_device(args.device_id, args.confirm)
            result = dict(device)
            print("旧凭据与订阅 token 已撤销；新凭据如下：")
            print_device(device, agent.load_config())
        elif args.command == "delete-device":
            agent.delete_device(args.device_id, args.confirm)
            print("设备、凭据、订阅与旧数据库备份已硬删除。")
        elif args.command == "update-user":
            agent.update_user(args)
            print("用户策略已更新。")
        elif args.command == "set-protocol":
            agent.set_protocol(args.user_id, args.protocol, args.enabled == "yes")
            print("协议权限已更新。")
        elif args.command == "delete-user":
            agent.delete_user(args.user_id, args.confirm)
            print("用户、设备、订阅与旧数据库备份已硬删除。")
        elif args.command in {"list-users", "status", "usage"}:
            result = agent.status_rows()
            if not args.json:
                print_status_table(result)
        elif args.command == "show-user":
            user = agent.db.connection.execute("SELECT * FROM users WHERE id=?", (args.user_id,)).fetchone()
            if not user:
                raise AgentError("用户不存在")
            devices = agent.db.connection.execute("SELECT * FROM devices WHERE user_id=? ORDER BY id", (args.user_id,)).fetchall()
            result = {"user": dict(user), "devices": [dict(item) for item in devices]}
            if not args.json:
                print(f"用户：{user['name']}（ID {user['id']}）")
                for device in devices:
                    print_device(device, agent.load_config())
                    print()
        elif args.command == "show-subscription":
            device = agent.db.connection.execute("SELECT * FROM devices WHERE id=?", (args.device_id,)).fetchone()
            if not device:
                raise AgentError("设备不存在")
            result = dict(device)
            if not args.json:
                print_device(device, agent.load_config())
        elif args.command == "reconcile":
            result = agent.reconcile()
            print(f"配置注入完成：{result}")
        elif args.command == "apply":
            result = agent.apply()
            print(f"配置已校验并应用：{result}")
        elif args.command == "maintenance":
            result = agent.maintenance_once()
            print(json.dumps(result, ensure_ascii=False))
        elif args.command == "backup":
            result = str(agent.backup_database())
            print(f"备份完成：{result}")
        elif args.command == "restore-database":
            agent.restore_database(args.path)
            result = {"restored": args.path}
            print("数据库备份已恢复。")
        elif args.command == "doctor":
            result = agent.doctor()
            if not args.json:
                labels = {
                    "database": "数据库完整性", "enabled": "模块状态",
                    "xray_config": "Xray 配置", "singbox_config": "Sing-box 配置",
                    "subscription_files": "设备订阅文件", "scheme": "订阅传输协议",
                    "port": "新设备订阅端口", "legacy_http_port": "旧订阅兼容端口",
                    "xray_validate": "Xray 配置校验", "singbox_validate": "Sing-box 配置校验",
                    "singbox_v2ray_api": "Sing-box 用户统计能力",
                    "singbox_stats_helper": "Sing-box 流量统计组件",
                }
                for key, value in result.items():
                    if isinstance(value, bool):
                        if key == "enabled":
                            value = "已启用" if value else "已停用"
                        else:
                            value = "正常" if value else "异常/未安装"
                    elif key == "database" and value == "ok":
                        value = "正常"
                    elif key == "scheme":
                        value = str(value).upper()
                    print(f"{labels.get(key, key)}：{value}")
        elif args.command == "set-module":
            config = agent.load_config()
            config["enabled"] = args.enabled == "yes"
            agent.save_config(config)
            result = {"enabled": config["enabled"]}
            print("模块已启用。" if config["enabled"] else "模块已停用。")
        elif args.command == "serve":
            serve(agent)
        if args.json and result is not None:
            print(json.dumps(result, ensure_ascii=False, indent=2))
        return 0
    except (AgentError, sqlite3.Error, json.JSONDecodeError) as exc:
        print(f"错误：{exc}", file=sys.stderr)
        return 1
    finally:
        agent.close()


if __name__ == "__main__":
    raise SystemExit(main())
