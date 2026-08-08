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


VERSION = "0.4.0"
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
VISIT_DETAIL_DAYS = 7
VISIT_SUMMARY_DAYS = 30
VISIT_EVENT_LIMIT = 100_000
VISIT_SUMMARY_LIMIT = 200_000
VISIT_LOG_MAX_BYTES = 10 * 1024 * 1024
VISIT_READ_MAX_BYTES = 4 * 1024 * 1024
VISIT_FILTER_MODE = "standard"
VISIT_MERGE_MINUTES = 10
VISIT_NOISE_SUFFIXES = frozenset({
    "doubleclick.net", "googlesyndication.com", "googleadservices.com",
    "adtrafficquality.google", "googletagmanager.com", "google-analytics.com",
    "clarity.ms", "cloudflareinsights.com", "visualwebsiteoptimizer.com",
    "adobedc.net", "adobedtm.com", "zi-scripts.com", "51.la", "owox.com",
    "mktoresp.com", "srv.stackadapt.com", "cookiehub.net", "cookiehub.eu",
})
VISIT_NOISE_EXACT = frozenset({
    "px.ads.linkedin.com", "snap.licdn.com", "connect.facebook.net",
    "a.nel.cloudflare.com",
})


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


def format_storage(value: int) -> str:
    return "0 B" if value <= 0 else format_size(value)


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


def print_visit_table(headers: tuple[str, ...], rows: list[tuple[str, ...]]) -> None:
    if not rows:
        print("暂无访问记录。")
        return
    widths = [display_width(header) for header in headers]
    for row in rows:
        widths = [max(current, display_width(value)) for current, value in zip(widths, row)]
    print("  ".join(display_pad(value, width) for value, width in zip(headers, widths)))
    for row in rows:
        print("  ".join(display_pad(value, width) for value, width in zip(row, widths)))


def print_visit_recent(rows: list[dict[str, Any]]) -> None:
    values = []
    for row in rows:
        timestamp = dt.datetime.fromtimestamp(row["occurred_at"], dt.timezone.utc).strftime("%m-%d %H:%M:%S")
        values.append((
            timestamp,
            f"{row['user_name']}/{row['device_name']}",
            row["core"],
            row["network"].upper(),
            row["inbound"],
            f"{row['domain']}:{row['port']}",
        ))
    print_visit_table(("时间(UTC)", "用户/设备", "内核", "网络", "入口", "目标域名"), values)


def print_visit_activity(rows: list[dict[str, Any]]) -> None:
    values = []
    for row in rows:
        first_seen = dt.datetime.fromtimestamp(row["first_seen"], dt.timezone.utc).strftime("%m-%d %H:%M:%S")
        last_seen = dt.datetime.fromtimestamp(row["last_seen"], dt.timezone.utc).strftime("%H:%M:%S")
        time_range = first_seen if row["first_seen"] == row["last_seen"] else f"{first_seen}-{last_seen}"
        networks = "/".join(
            name for name, present in (("TCP", row["has_tcp"]), ("UDP", row["has_udp"])) if present
        )
        values.append((
            time_range,
            f"{row['user_name']}/{row['device_name']}",
            f"{row['domain']}:{row['port']}",
            str(row["connections"]),
            networks or "-",
            str(row["inbounds"]),
        ))
    print_visit_table(("时间段(UTC)", "用户/设备", "目标域名", "连接数", "网络", "入口数"), values)


def print_visit_top(rows: list[dict[str, Any]], group: str) -> None:
    values = []
    for row in rows:
        last_seen = dt.datetime.fromtimestamp(row["last_seen"], dt.timezone.utc).strftime("%m-%d %H:%M")
        if group == "user":
            values.append((
                str(row["user_id"]), row["user_name"], str(row["domains"]),
                str(row["connections"]), last_seen,
            ))
        else:
            values.append((
                f"{row['domain']}:{row['port']}", str(row["users"]),
                str(row["connections"]), last_seen,
            ))
    if group == "user":
        print_visit_table(("ID", "用户", "域名数", "连接次数", "最后访问(UTC)"), values)
    else:
        print_visit_table(("域名", "用户数", "连接次数", "最后访问(UTC)"), values)


def print_visit_filter_status(settings: dict[str, Any]) -> None:
    mode = "标准过滤" if settings["filter_mode"] == "standard" else "不过滤"
    print(f"智能过滤：{mode}")
    print(f"活动合并窗口：{settings['merge_minutes']} 分钟")
    hidden = settings["hidden_domains"]
    allowed = settings["allowed_domains"]
    print("自定义隐藏：" + (" ".join(hidden) if hidden else "无"))
    print("始终显示：" + (" ".join(allowed) if allowed else "无"))
    print("说明：过滤只影响智能视图，不阻断代理流量，不删除原始记录。")


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
            CREATE TABLE IF NOT EXISTS visit_events (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              occurred_at INTEGER NOT NULL,
              device_id INTEGER NOT NULL REFERENCES devices(id) ON DELETE CASCADE,
              core TEXT NOT NULL,
              network TEXT NOT NULL,
              inbound TEXT NOT NULL,
              domain TEXT NOT NULL,
              port INTEGER NOT NULL
            );
            CREATE INDEX IF NOT EXISTS visit_events_time_idx
              ON visit_events(occurred_at DESC);
            CREATE INDEX IF NOT EXISTS visit_events_device_time_idx
              ON visit_events(device_id, occurred_at DESC);
            CREATE INDEX IF NOT EXISTS visit_events_domain_time_idx
              ON visit_events(domain, occurred_at DESC);
            CREATE TABLE IF NOT EXISTS visit_daily (
              day TEXT NOT NULL,
              device_id INTEGER NOT NULL REFERENCES devices(id) ON DELETE CASCADE,
              core TEXT NOT NULL,
              network TEXT NOT NULL,
              inbound TEXT NOT NULL,
              domain TEXT NOT NULL,
              port INTEGER NOT NULL,
              connections INTEGER NOT NULL DEFAULT 0,
              first_seen INTEGER NOT NULL,
              last_seen INTEGER NOT NULL,
              PRIMARY KEY(day,device_id,core,network,inbound,domain,port)
            );
            CREATE INDEX IF NOT EXISTS visit_daily_day_idx
              ON visit_daily(day DESC);
            UPDATE schema_meta SET version=2 WHERE version<2;
            """
        )
        user_columns = {row[1] for row in self.connection.execute("PRAGMA table_info(users)")}
        if "cluster_managed" not in user_columns:
            self.connection.execute("ALTER TABLE users ADD COLUMN cluster_managed INTEGER NOT NULL DEFAULT 0")
        if "cluster_key" not in user_columns:
            self.connection.execute("ALTER TABLE users ADD COLUMN cluster_key TEXT")
        device_columns = {row[1] for row in self.connection.execute("PRAGMA table_info(devices)")}
        if "cluster_key" not in device_columns:
            self.connection.execute("ALTER TABLE devices ADD COLUMN cluster_key TEXT")
        self.connection.execute(
            "CREATE UNIQUE INDEX IF NOT EXISTS users_cluster_key_idx ON users(cluster_key) WHERE cluster_key IS NOT NULL"
        )
        self.connection.execute(
            "CREATE UNIQUE INDEX IF NOT EXISTS devices_cluster_key_idx ON devices(cluster_key) WHERE cluster_key IS NOT NULL"
        )
        defaults = {
            "visit_monitor_enabled": "0",
            "visit_detail_days": str(VISIT_DETAIL_DAYS),
            "visit_summary_days": str(VISIT_SUMMARY_DAYS),
            "visit_event_limit": str(VISIT_EVENT_LIMIT),
            "visit_summary_limit": str(VISIT_SUMMARY_LIMIT),
            "visit_log_max_bytes": str(VISIT_LOG_MAX_BYTES),
            "visit_filter_mode": VISIT_FILTER_MODE,
            "visit_merge_minutes": str(VISIT_MERGE_MINUTES),
            "visit_filter_hidden": "[]",
            "visit_filter_allowed": "[]",
        }
        self.connection.executemany(
            "INSERT OR IGNORE INTO settings(key,value) VALUES(?,?)",
            defaults.items(),
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
        self._cluster_refresh_lock = threading.Lock()
        self._cluster_refresh_started: dict[str, float] = {}
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

    def set_subscription_port(self, port: int, public_port: int) -> dict[str, int]:
        if not 1 <= port <= 65535 or not 1 <= public_port <= 65535:
            raise AgentError("订阅端口必须在 1-65535 范围内")
        config = self.load_config()
        config["port"] = port
        config["public_port"] = public_port
        self.save_config(config)
        with self.db.connection:
            self.db.audit(
                "subscription.port",
                "module",
                f"internal={port},public={public_port}",
            )
        self.sync_legacy_subscription_state()
        return {"port": port, "public_port": public_port}

    def local_subscription_device(self) -> sqlite3.Row:
        config = self.load_config()
        device = self.db.connection.execute(
            "SELECT * FROM devices WHERE legacy=1 ORDER BY id LIMIT 1"
        ).fetchone()
        if not device and config.get("legacy_token"):
            device = self.db.connection.execute(
                "SELECT * FROM devices WHERE token=? ORDER BY id LIMIT 1",
                (config["legacy_token"],),
            ).fetchone()
        if not device:
            devices = self.db.connection.execute(
                "SELECT * FROM devices ORDER BY id LIMIT 2"
            ).fetchall()
            if len(devices) == 1:
                device = devices[0]
        if not device:
            raise AgentError("没有唯一的本机设备，请在多用户管理中按设备查看订阅")
        return device

    def sync_legacy_subscription_state(self) -> dict[str, int]:
        config = self.load_config()
        device = self.local_subscription_device()
        token = str(device["token"])
        if config.get("legacy_token") != token or config.get("version") != VERSION:
            config["legacy_token"] = token
            config["version"] = VERSION
            self.save_config(config)
        port = int(config["port"])
        public_port = int(config.get("public_port") or port)
        atomic_write(self.root / "subtoken.log", token + "\n", 0o600)
        atomic_write(self.root / "subport.log", f"{port}\n", 0o600)
        return {
            "device_id": int(device["id"]),
            "port": port,
            "public_port": public_port,
        }

    def multiuser_enabled(self) -> bool:
        try:
            return bool(self.load_config().get("enabled"))
        except (AgentError, OSError, json.JSONDecodeError):
            return False

    def visit_log_paths(self) -> dict[str, Path]:
        return {
            "xray": self.data_dir / "xray-access.log",
            "singbox": self.data_dir / "singbox-access.log",
        }

    def secure_sensitive_files(self) -> None:
        for directory in (self.module, self.data_dir, self.backups):
            if directory.exists():
                with contextlib.suppress(OSError):
                    os.chmod(directory, 0o700)
        paths = [
            self.db.path,
            self.db.path.with_name(self.db.path.name + "-wal"),
            self.db.path.with_name(self.db.path.name + "-shm"),
            *self.visit_log_paths().values(),
            *self.backups.glob("db-*.sqlite3"),
        ]
        for path in paths:
            if path.exists():
                with contextlib.suppress(OSError):
                    os.chmod(path, 0o600)

    @staticmethod
    def normalize_visit_domain(value: str) -> str:
        domain = value.strip().lower().rstrip(".")
        if domain.startswith("*."):
            domain = domain[2:]
        try:
            domain = domain.encode("idna").decode("ascii")
            ipaddress.ip_address(domain)
        except UnicodeError as exc:
            raise AgentError("域名格式无效") from exc
        except ValueError:
            pass
        else:
            raise AgentError("过滤规则只接受域名，不接受 IP")
        if len(domain) > 253 or "." not in domain:
            raise AgentError("请输入完整域名")
        labels = domain.split(".")
        if any(
            not label or len(label) > 63 or not re.fullmatch(r"[a-z0-9](?:[a-z0-9-]*[a-z0-9])?", label)
            for label in labels
        ):
            raise AgentError("域名格式无效")
        return domain

    def _visit_rule_setting(self, key: str) -> list[str]:
        try:
            values = json.loads(self.db.setting(key, "[]"))
        except json.JSONDecodeError:
            values = []
        if not isinstance(values, list):
            return []
        result = []
        for value in values:
            try:
                normalized = self.normalize_visit_domain(str(value))
            except AgentError:
                continue
            if normalized not in result:
                result.append(normalized)
        return result[:256]

    def visit_monitor_settings(self) -> dict[str, Any]:
        def number(key: str, default: int, minimum: int, maximum: int) -> int:
            try:
                value = int(self.db.setting(key, str(default)))
            except ValueError:
                value = default
            return min(maximum, max(minimum, value))

        paths = self.visit_log_paths()
        filter_mode = self.db.setting("visit_filter_mode", VISIT_FILTER_MODE)
        if filter_mode not in {"standard", "off"}:
            filter_mode = VISIT_FILTER_MODE
        return {
            "enabled": self.db.setting("visit_monitor_enabled", "0") == "1",
            "detail_days": number("visit_detail_days", VISIT_DETAIL_DAYS, 1, 30),
            "summary_days": number("visit_summary_days", VISIT_SUMMARY_DAYS, 1, 365),
            "event_limit": number("visit_event_limit", VISIT_EVENT_LIMIT, 1_000, 1_000_000),
            "summary_limit": number("visit_summary_limit", VISIT_SUMMARY_LIMIT, 1_000, 2_000_000),
            "log_max_bytes": number(
                "visit_log_max_bytes", VISIT_LOG_MAX_BYTES, 1024 * 1024, 100 * 1024 * 1024
            ),
            "filter_mode": filter_mode,
            "merge_minutes": number("visit_merge_minutes", VISIT_MERGE_MINUTES, 1, 60),
            "hidden_domains": self._visit_rule_setting("visit_filter_hidden"),
            "allowed_domains": self._visit_rule_setting("visit_filter_allowed"),
            "xray_log": str(paths["xray"]),
            "singbox_log": str(paths["singbox"]),
        }

    def set_visit_monitor(self, enabled: bool, detail_days: int, summary_days: int) -> dict[str, Any]:
        if not 1 <= detail_days <= 30:
            raise AgentError("访问明细保留范围应为 1-30 天")
        if not 1 <= summary_days <= 365:
            raise AgentError("访问汇总保留范围应为 1-365 天")
        if summary_days < detail_days:
            raise AgentError("访问汇总保留天数不能少于明细保留天数")
        with self.db.connection:
            self.db.set_setting("visit_monitor_enabled", int(enabled))
            self.db.set_setting("visit_detail_days", detail_days)
            self.db.set_setting("visit_summary_days", summary_days)
            self.db.audit(
                "visit-monitor.configure",
                "module",
                f"enabled={int(enabled)},detail_days={detail_days},summary_days={summary_days}",
            )
        return self.visit_monitor_settings()

    def set_visit_filter(self, mode: str | None, merge_minutes: int | None) -> dict[str, Any]:
        current = self.visit_monitor_settings()
        mode = mode if mode is not None else current["filter_mode"]
        merge_minutes = merge_minutes if merge_minutes is not None else current["merge_minutes"]
        if mode not in {"standard", "off"}:
            raise AgentError("过滤模式必须是 standard 或 off")
        if not 1 <= merge_minutes <= 60:
            raise AgentError("合并窗口必须是 1-60 分钟")
        with self.db.connection:
            self.db.set_setting("visit_filter_mode", mode)
            self.db.set_setting("visit_merge_minutes", merge_minutes)
            self.db.audit(
                "visit-monitor.filter-config", "module",
                f"mode={mode},merge_minutes={merge_minutes}",
            )
        return self.visit_monitor_settings()

    def update_visit_filter_rule(self, action: str, value: str) -> dict[str, Any]:
        domain = self.normalize_visit_domain(value)
        mapping = {
            "add-hide": ("visit_filter_hidden", True),
            "remove-hide": ("visit_filter_hidden", False),
            "add-show": ("visit_filter_allowed", True),
            "remove-show": ("visit_filter_allowed", False),
        }
        if action not in mapping:
            raise AgentError("未知的域名规则操作")
        key, adding = mapping[action]
        values = self._visit_rule_setting(key)
        if adding and domain not in values:
            if len(values) >= 256:
                raise AgentError("自定义域名规则最多 256 条")
            values.append(domain)
        elif not adding and domain in values:
            values.remove(domain)
        with self.db.connection:
            self.db.set_setting(key, json.dumps(sorted(values), ensure_ascii=False))
            self.db.audit("visit-monitor.filter-rule", domain, action)
        return self.visit_monitor_settings()

    def reset_visit_filter_rules(self) -> dict[str, Any]:
        with self.db.connection:
            self.db.set_setting("visit_filter_hidden", "[]")
            self.db.set_setting("visit_filter_allowed", "[]")
            self.db.audit("visit-monitor.filter-reset", "module")
        return self.visit_monitor_settings()

    def _configure_visit_log(
        self,
        data: dict[str, Any],
        core: str,
        enabled: bool,
        owner_field: str,
        desired: dict[str, Any],
    ) -> None:
        backup_key = f"visit_{core}_log_fields_before"
        log = data.get("log")
        owned = isinstance(log, dict) and log.get(owner_field) == desired[owner_field]
        backup = self.db.setting(backup_key, "")
        if enabled:
            if not owned and not backup:
                original = log if isinstance(log, dict) else {}
                snapshot = {
                    "log_present": isinstance(log, dict),
                    "fields": {
                        key: {"present": key in original, "value": original.get(key)}
                        for key in desired
                    },
                }
                self.db.set_setting(backup_key, json.dumps(snapshot, ensure_ascii=False))
            if not isinstance(log, dict):
                log = {}
                data["log"] = log
            log.update(desired)
            return

        if owned:
            restored = False
            if backup:
                try:
                    snapshot = json.loads(backup)
                    fields = snapshot["fields"]
                    for key, module_value in desired.items():
                        # Keep an operator's explicit change made while monitoring was active.
                        if key != owner_field and log.get(key) != module_value:
                            continue
                        state = fields[key]
                        if state["present"]:
                            log[key] = state["value"]
                        else:
                            log.pop(key, None)
                    if not snapshot["log_present"] and not log:
                        data.pop("log", None)
                    restored = True
                except (KeyError, TypeError, ValueError, json.JSONDecodeError):
                    restored = False
            if not restored:
                for key, module_value in desired.items():
                    if log.get(key) == module_value:
                        log.pop(key, None)
                if not log:
                    data.pop("log", None)
        if backup:
            self.db.connection.execute("DELETE FROM settings WHERE key=?", (backup_key,))

    def _configure_xray_visit_identity(
        self, data: dict[str, Any], devices: list[dict[str, Any]], enabled: bool
    ) -> None:
        backup_key = "visit_xray_identity_before"
        try:
            snapshot = json.loads(self.db.setting(backup_key, "") or "{}")
        except (TypeError, ValueError, json.JSONDecodeError):
            snapshot = {}
        if not isinstance(snapshot, dict):
            snapshot = {}
        client_states = snapshot.setdefault("clients", [])
        sniffing_states = snapshot.setdefault("sniffing", [])
        if not isinstance(client_states, list) or not isinstance(sniffing_states, list):
            client_states, sniffing_states = [], []
            snapshot = {"clients": client_states, "sniffing": sniffing_states}
        device_by_uuid = {item["uuid"]: item for item in devices}

        if enabled:
            client_index = {
                (item.get("tag"), item.get("client_id")): item
                for item in client_states if isinstance(item, dict)
            }
            sniffing_index = {
                item.get("tag"): item
                for item in sniffing_states if isinstance(item, dict)
            }
            for inbound in data.get("inbounds", []):
                tag = str(inbound.get("tag", ""))
                if tag not in XRAY_TAG_PROTOCOL:
                    continue
                settings = inbound.get("settings")
                if isinstance(settings, dict):
                    clients = settings.get("clients")
                    if isinstance(clients, list):
                        for client in clients:
                            if not isinstance(client, dict):
                                continue
                            client_id = str(client.get("id", ""))
                            device = device_by_uuid.get(client_id)
                            if not device:
                                continue
                            key = (tag, client_id)
                            applied = device["identity"]
                            state = client_index.get(key)
                            if state is None:
                                state = {
                                    "tag": tag,
                                    "client_id": client_id,
                                    "present": "email" in client,
                                    "value": client.get("email"),
                                    "applied": applied,
                                }
                                client_states.append(state)
                                client_index[key] = state
                            else:
                                state["applied"] = applied
                            client["email"] = applied

                current = inbound.get("sniffing")
                desired = copy.deepcopy(current) if isinstance(current, dict) else {}
                desired["enabled"] = True
                overrides = desired.get("destOverride")
                if not isinstance(overrides, list):
                    overrides = []
                desired["destOverride"] = list(dict.fromkeys([*overrides, "http", "tls", "quic"]))
                desired["metadataOnly"] = False
                state = sniffing_index.get(tag)
                if state is None:
                    state = {
                        "tag": tag,
                        "present": "sniffing" in inbound,
                        "value": copy.deepcopy(current),
                        "applied": copy.deepcopy(desired),
                    }
                    sniffing_states.append(state)
                    sniffing_index[tag] = state
                else:
                    state["applied"] = copy.deepcopy(desired)
                inbound["sniffing"] = desired
            if client_states or sniffing_states:
                self.db.set_setting(backup_key, json.dumps(snapshot, ensure_ascii=False))
            return

        inbounds = {
            str(item.get("tag", "")): item
            for item in data.get("inbounds", []) if isinstance(item, dict)
        }
        for state in client_states:
            if not isinstance(state, dict):
                continue
            inbound = inbounds.get(str(state.get("tag", "")))
            settings = inbound.get("settings") if inbound else None
            clients = settings.get("clients") if isinstance(settings, dict) else None
            if not isinstance(clients, list):
                continue
            for client in clients:
                if not isinstance(client, dict) or str(client.get("id", "")) != str(state.get("client_id", "")):
                    continue
                if client.get("email") != state.get("applied"):
                    break
                if state.get("present"):
                    client["email"] = state.get("value")
                else:
                    client.pop("email", None)
                break
        for state in sniffing_states:
            if not isinstance(state, dict):
                continue
            inbound = inbounds.get(str(state.get("tag", "")))
            if not inbound or inbound.get("sniffing") != state.get("applied"):
                continue
            if state.get("present"):
                inbound["sniffing"] = state.get("value")
            else:
                inbound.pop("sniffing", None)
        if self.db.setting(backup_key, ""):
            self.db.connection.execute("DELETE FROM settings WHERE key=?", (backup_key,))

    def _configure_singbox_visit_identity(
        self, data: dict[str, Any], devices: list[dict[str, Any]], enabled: bool
    ) -> None:
        backup_key = "visit_singbox_identity_before"
        try:
            states = json.loads(self.db.setting(backup_key, "") or "[]")
        except (TypeError, ValueError, json.JSONDecodeError):
            states = []
        if not isinstance(states, list):
            states = []
        supported = {"hysteria2", "tuic", "anytls", "vmess"}
        device_by_uuid = {item["uuid"]: item for item in devices}

        if enabled:
            state_index = {
                (item.get("tag"), item.get("credential")): item
                for item in states if isinstance(item, dict)
            }
            for inbound in data.get("inbounds", []):
                if not isinstance(inbound, dict) or inbound.get("type") not in supported:
                    continue
                tag = str(inbound.get("tag", ""))
                users = inbound.get("users")
                if not isinstance(users, list):
                    continue
                for user in users:
                    if not isinstance(user, dict):
                        continue
                    credential = str(user.get("uuid") or user.get("username") or user.get("password") or "")
                    device = device_by_uuid.get(credential)
                    if not device:
                        continue
                    key = (tag, credential)
                    applied = device["identity"]
                    state = state_index.get(key)
                    if state is None:
                        state = {
                            "tag": tag,
                            "credential": credential,
                            "present": "name" in user,
                            "value": user.get("name"),
                            "applied": applied,
                        }
                        states.append(state)
                        state_index[key] = state
                    else:
                        state["applied"] = applied
                    user["name"] = applied
            if states:
                self.db.set_setting(backup_key, json.dumps(states, ensure_ascii=False))
            route = data.setdefault("route", {})
            rules = route.setdefault("rules", [])
            if not any(isinstance(rule, dict) and rule.get("action") == "sniff" for rule in rules):
                rules.insert(0, {"action": "sniff"})
                self.db.set_setting("visit_singbox_sniff_inserted", 1)
            return

        inbounds = {
            str(item.get("tag", "")): item
            for item in data.get("inbounds", []) if isinstance(item, dict)
        }
        for state in states:
            if not isinstance(state, dict):
                continue
            inbound = inbounds.get(str(state.get("tag", "")))
            users = inbound.get("users") if inbound else None
            if not isinstance(users, list):
                continue
            for user in users:
                if not isinstance(user, dict):
                    continue
                credential = str(user.get("uuid") or user.get("username") or user.get("password") or "")
                if credential != str(state.get("credential", "")) or user.get("name") != state.get("applied"):
                    continue
                if state.get("present"):
                    user["name"] = state.get("value")
                else:
                    user.pop("name", None)
                break
        if self.db.setting(backup_key, ""):
            self.db.connection.execute("DELETE FROM settings WHERE key=?", (backup_key,))
        if self.db.setting("visit_singbox_sniff_inserted", "") == "1":
            route = data.get("route")
            rules = route.get("rules") if isinstance(route, dict) else None
            if isinstance(rules, list):
                for index, rule in enumerate(rules):
                    if rule == {"action": "sniff"}:
                        rules.pop(index)
                        break
            self.db.connection.execute(
                "DELETE FROM settings WHERE key='visit_singbox_sniff_inserted'"
            )

    def _reconcile_visit_xray(
        self, data: dict[str, Any], devices: list[dict[str, Any]]
    ) -> dict[str, Any]:
        monitor = self.visit_monitor_settings()
        self._configure_visit_log(
            data,
            "xray",
            monitor["enabled"],
            "access",
            {
                "access": monitor["xray_log"],
                # Xray 26.3.27 does not create access logs when loglevel is "none".
                "loglevel": "warning",
            },
        )
        self._configure_xray_visit_identity(data, devices, monitor["enabled"])
        return data

    def _reconcile_visit_singbox(
        self, data: dict[str, Any], devices: list[dict[str, Any]]
    ) -> dict[str, Any]:
        monitor = self.visit_monitor_settings()
        self._configure_visit_log(
            data,
            "singbox",
            monitor["enabled"],
            "output",
            {
                "disabled": False,
                "level": "info",
                "output": monitor["singbox_log"],
                "timestamp": True,
            },
        )
        self._configure_singbox_visit_identity(data, devices, monitor["enabled"])
        return data

    def _ensure_legacy_identity(
        self, legacy_uuid: str | None = None, legacy_token: str | None = None
    ) -> sqlite3.Row:
        legacy_uuid = legacy_uuid or self._read_text("uuid")
        if not legacy_uuid:
            raise AgentError("未找到本机 UUID，请先安装至少一个代理协议")
        legacy_token = legacy_token or self._read_text("subtoken.log") or legacy_uuid
        now = utc_now()
        user = self.db.connection.execute(
            "SELECT * FROM users WHERE name='legacy-admin'"
        ).fetchone()
        if user:
            user_id = user["id"]
        else:
            cursor = self.db.connection.execute(
                "INSERT INTO users(name,reset_day,max_devices,created_at,updated_at) VALUES(?,?,?,?,?)",
                ("legacy-admin", 1, 3, now, now),
            )
            user_id = cursor.lastrowid
        self._insert_protocol_defaults(user_id)
        device = self.db.connection.execute(
            "SELECT * FROM devices WHERE user_id=? AND legacy=1 ORDER BY id LIMIT 1",
            (user_id,),
        ).fetchone()
        if not device:
            device = self.db.connection.execute(
                "SELECT * FROM devices WHERE uuid=?", (legacy_uuid,)
            ).fetchone()
        if device and device["user_id"] != user_id:
            raise AgentError("本机 UUID 已属于其他用户，无法创建本机监控身份")
        if not device:
            self.db.connection.execute(
                "INSERT INTO devices(user_id,name,uuid,password,ss_password,token,enabled,legacy,created_at,updated_at) "
                "VALUES(?,?,?,?,?,?,?,?,?,?)",
                (
                    user_id,
                    "legacy-device",
                    legacy_uuid,
                    legacy_uuid,
                    base64.b64encode(secrets.token_bytes(16)).decode(),
                    legacy_token,
                    1,
                    1,
                    now,
                    now,
                ),
            )
            device = self.db.connection.execute(
                "SELECT * FROM devices WHERE uuid=?", (legacy_uuid,)
            ).fetchone()
        elif not device["legacy"]:
            self.db.connection.execute(
                "UPDATE devices SET legacy=1,updated_at=? WHERE id=?",
                (now, device["id"]),
            )
            device = self.db.connection.execute(
                "SELECT * FROM devices WHERE id=?", (device["id"],)
            ).fetchone()
        assert device is not None
        return device

    def initialize_visit(self) -> dict[str, Any]:
        self.module.mkdir(parents=True, exist_ok=True)
        self.generated.mkdir(parents=True, exist_ok=True)
        self.backups.mkdir(parents=True, exist_ok=True)
        with self.db.connection:
            device = self._ensure_legacy_identity()
            self.db.audit("visit-monitor.init", "module", f"device={device['id']}")
        self.secure_sensitive_files()
        return {
            "user_id": device["user_id"],
            "device_id": device["id"],
            "uuid": device["uuid"],
        }

    def initialize(self, args: argparse.Namespace) -> dict[str, Any]:
        self.module.mkdir(parents=True, exist_ok=True)
        self.generated.mkdir(parents=True, exist_ok=True)
        self.backups.mkdir(parents=True, exist_ok=True)
        config = self._subscription_config(args, enabled=True, subscription_only=False)
        if args.scheme == "https":
            if not (config["certificate"] and config["private_key"]):
                raise AgentError("HTTPS 订阅缺少证书或私钥")
            if not Path(config["certificate"]).is_file() or not Path(config["private_key"]).is_file():
                raise AgentError("HTTPS 订阅证书文件不存在")
        self.save_config(config)
        with self.db.connection:
            self._ensure_legacy_identity(config["legacy_uuid"], config["legacy_token"])
            self.db.audit("module.init", "module", f"scheme={args.scheme},port={args.port}")
        self.sync_legacy_subscription_state()
        self.backup_database()
        self.secure_sensitive_files()
        return config

    def initialize_subscription_only(self, args: argparse.Namespace) -> dict[str, Any]:
        """Start subscription delivery without managing proxy cores or traffic."""
        self.module.mkdir(parents=True, exist_ok=True)
        self.generated.mkdir(parents=True, exist_ok=True)
        self.backups.mkdir(parents=True, exist_ok=True)
        config = self._subscription_config(args, enabled=False, subscription_only=True)
        if args.scheme == "https":
            if not (config["certificate"] and config["private_key"]):
                raise AgentError("HTTPS 订阅缺少证书或私钥")
            if not Path(config["certificate"]).is_file() or not Path(config["private_key"]).is_file():
                raise AgentError("HTTPS 订阅证书文件不存在")
        self.save_config(config)
        with self.db.connection:
            self._ensure_legacy_identity(config["legacy_uuid"], config["legacy_token"])
            self.db.audit("subscription-only.init", "module", f"scheme={args.scheme},port={args.port}")
        self.sync_legacy_subscription_state()
        self.render_all_subscriptions()
        self.backup_database()
        self.secure_sensitive_files()
        return config

    def _subscription_config(
        self, args: argparse.Namespace, *, enabled: bool, subscription_only: bool
    ) -> dict[str, Any]:
        legacy_uuid = args.legacy_uuid or self._read_text("uuid") or str(__import__("uuid").uuid4())
        legacy_token = args.legacy_token or self._read_text("subtoken.log") or legacy_uuid
        return {
            "version": VERSION,
            "enabled": enabled,
            "subscription_only": subscription_only,
            "bind": args.bind,
            "port": args.port,
            "public_port": args.public_port or args.port,
            "legacy_http_port": max(0, args.legacy_http_port),
            "legacy_http_public_port": max(0, args.legacy_http_public_port or args.legacy_http_port),
            "scheme": args.scheme,
            "public_host": args.public_host,
            "certificate": args.certificate or "",
            "private_key": args.private_key or "",
            "xray_api": getattr(args, "xray_api", "127.0.0.1:10085"),
            "singbox_api": getattr(args, "singbox_api", "127.0.0.1:10086"),
            "poll_interval": max(15, getattr(args, "poll_interval", 30)),
            "legacy_uuid": legacy_uuid,
            "legacy_token": legacy_token,
            "ss_port": max(0, getattr(args, "ss_port", 0)),
            "ss_public_port": max(0, getattr(args, "ss_public_port", 0) or getattr(args, "ss_port", 0)),
            "ss_server_password": getattr(args, "ss_server_password", None) or base64.b64encode(secrets.token_bytes(16)).decode(),
        }

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
        user = self.db.connection.execute("SELECT * FROM users WHERE id=?", (user_id,)).fetchone()
        if user and user["cluster_managed"]:
            raise AgentError("该用户由主 VPS 统一管理，请在主 VPS 修改")
        with self.db.connection:
            device = self._create_device(user_id, name)
            self.db.audit("device.add", str(device["id"]), f"user={user_id}")
        self.backup_database()
        return device

    def update_device(self, device_id: int, name: str | None = None, enabled: bool | None = None) -> sqlite3.Row:
        device = self.db.connection.execute("SELECT * FROM devices WHERE id=?", (device_id,)).fetchone()
        if not device:
            raise AgentError("设备不存在")
        user = self.db.connection.execute("SELECT * FROM users WHERE id=?", (device["user_id"],)).fetchone()
        if user["cluster_managed"]:
            raise AgentError("该设备由主 VPS 统一管理，请在主 VPS 修改")
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
        user = self.db.connection.execute("SELECT * FROM users WHERE id=?", (device["user_id"],)).fetchone()
        if user["cluster_managed"]:
            raise AgentError("该设备由主 VPS 统一管理，请在主 VPS 修改")
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
        user = self.db.connection.execute("SELECT * FROM users WHERE id=?", (device["user_id"],)).fetchone()
        if user["cluster_managed"]:
            raise AgentError("该设备由主 VPS 统一管理，请在主 VPS 修改")
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
        if row["cluster_managed"]:
            raise AgentError("该用户由主 VPS 统一管理，请在主 VPS 修改")
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
        user = self.db.connection.execute("SELECT * FROM users WHERE id=?", (user_id,)).fetchone()
        if not user:
            raise AgentError("用户不存在")
        if user["cluster_managed"]:
            raise AgentError("该用户由主 VPS 统一管理，请在主 VPS 修改")
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
        if user["cluster_managed"]:
            raise AgentError("该用户由主 VPS 统一管理，请在主 VPS 修改")
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

    def export_cluster_users(self, user_ids: list[int] | None = None) -> dict[str, Any]:
        params: list[Any] = []
        where = "WHERE cluster_managed=0"
        if user_ids is not None:
            unique = list(dict.fromkeys(user_ids))
            if not unique:
                return {"schema_version": 1, "users": []}
            where += " AND id IN (%s)" % ",".join("?" for _ in unique)
            params.extend(unique)
        users: list[dict[str, Any]] = []
        for user in self.db.connection.execute(f"SELECT * FROM users {where} ORDER BY id", params):
            devices = [dict(row) for row in self.db.connection.execute(
                "SELECT name,uuid,password,ss_password,token,enabled FROM devices WHERE user_id=? ORDER BY id",
                (user["id"],),
            )]
            for device in devices:
                device["key"] = device["uuid"]
            permissions = {
                row["protocol"]: bool(row["enabled"])
                for row in self.db.connection.execute(
                    "SELECT protocol,enabled FROM protocol_permissions WHERE user_id=?", (user["id"],)
                )
            }
            users.append({
                "key": str(user["id"]), "name": user["name"],
                "manual_disabled": bool(user["manual_disabled"]),
                "lifetime_quota": int(user["lifetime_quota"]),
                "monthly_quota": int(user["monthly_quota"]),
                "reset_day": int(user["reset_day"]), "expires_at": user["expires_at"],
                "max_devices": max(int(user["max_devices"]), len(devices)),
                "devices": devices, "permissions": permissions,
            })
        return {"schema_version": 1, "users": users}

    @staticmethod
    def _validate_cluster_bundle(bundle: dict[str, Any], origin: str) -> list[dict[str, Any]]:
        if int(bundle.get("schema_version", 0)) != 1:
            raise AgentError("主 VPS 用户数据版本不兼容")
        if not re.fullmatch(r"[0-9a-f]{32}", origin):
            raise AgentError("主 VPS 集群身份无效")
        users = bundle.get("users")
        if not isinstance(users, list) or len(users) > 1000:
            raise AgentError("主 VPS 用户数据无效")
        normalized: list[dict[str, Any]] = []
        seen_users: set[str] = set()
        seen_credentials: set[str] = set()
        for raw in users:
            if not isinstance(raw, dict):
                raise AgentError("用户数据必须是对象")
            key = str(raw.get("key", ""))
            name = str(raw.get("name", "")).strip()
            if not re.fullmatch(r"[0-9]{1,18}", key) or key in seen_users or not name or len(name) > 128:
                raise AgentError("用户标识或名称无效")
            seen_users.add(key)
            reset_day = int(raw.get("reset_day", 1))
            max_devices = int(raw.get("max_devices", 3))
            devices = raw.get("devices")
            if reset_day not in range(1, 29) or not isinstance(devices, list) or len(devices) > 64:
                raise AgentError(f"用户 {name} 的策略或设备数无效")
            max_devices = max(max_devices, len(devices), 1)
            if max_devices > 64:
                raise AgentError("设备上限无效")
            checked_devices: list[dict[str, Any]] = []
            seen_device_keys: set[str] = set()
            for index, device in enumerate(devices):
                if not isinstance(device, dict):
                    raise AgentError("设备数据无效")
                if "key" in device:
                    device_key = str(device["key"]).strip()
                    try:
                        device_key = str(__import__("uuid").UUID(device_key))
                    except ValueError:
                        pass
                    if not re.fullmatch(r"[A-Za-z0-9][A-Za-z0-9._:-]{0,127}", device_key):
                        raise AgentError("设备稳定标识无效")
                else:
                    device_key = str(index)
                if device_key in seen_device_keys:
                    raise AgentError("同一用户的设备稳定标识重复")
                seen_device_keys.add(device_key)
                device_name = str(device.get("name", "")).strip()
                device_uuid = str(device.get("uuid", ""))
                try:
                    device_uuid = str(__import__("uuid").UUID(device_uuid))
                except ValueError as exc:
                    raise AgentError("设备 UUID 无效") from exc
                password = str(device.get("password", ""))
                ss_password = str(device.get("ss_password", ""))
                token = str(device.get("token", ""))
                if (not device_name or len(device_name) > 128 or not 8 <= len(password) <= 256
                        or not 8 <= len(ss_password) <= 256 or not re.fullmatch(r"[A-Za-z0-9_-]{16,128}", token)):
                    raise AgentError("设备凭据无效")
                for value in (device_uuid, token):
                    if value in seen_credentials:
                        raise AgentError("设备 UUID 或订阅 token 重复")
                    seen_credentials.add(value)
                checked_devices.append({
                    "key": device_key, "name": device_name, "uuid": device_uuid,
                    "password": password, "ss_password": ss_password, "token": token,
                    "enabled": int(bool(device.get("enabled", True))),
                })
            permissions = raw.get("permissions") if isinstance(raw.get("permissions"), dict) else {}
            normalized.append({
                "key": key, "name": name, "manual_disabled": int(bool(raw.get("manual_disabled"))),
                "lifetime_quota": max(0, int(raw.get("lifetime_quota", 0))),
                "monthly_quota": max(0, int(raw.get("monthly_quota", 0))),
                "reset_day": reset_day, "expires_at": raw.get("expires_at"),
                "max_devices": max_devices, "devices": checked_devices,
                "permissions": {key: bool(value) for key, value in permissions.items() if key in PROTOCOLS},
            })
        return normalized

    def import_cluster_users(self, bundle: dict[str, Any], origin: str) -> dict[str, int]:
        users = self._validate_cluster_bundle(bundle, origin)
        prefix = f"{origin}:user:"
        keep_users: set[str] = set()
        keep_devices: set[str] = set()
        now = utc_now()
        with self.db.connection:
            for item in users:
                user_key = prefix + item["key"]
                keep_users.add(user_key)
                row = self.db.connection.execute("SELECT * FROM users WHERE cluster_key=?", (user_key,)).fetchone()
                if row is None:
                    display_name = item["name"]
                    collision = self.db.connection.execute(
                        "SELECT 1 FROM users WHERE name=? COLLATE NOCASE", (display_name,)
                    ).fetchone()
                    if collision:
                        display_name = f"{display_name} [主VPS-{origin[:6]}]"
                    cursor = self.db.connection.execute(
                        """INSERT INTO users(name,manual_disabled,lifetime_quota,monthly_quota,reset_day,
                        expires_at,max_devices,created_at,updated_at,cluster_managed,cluster_key)
                        VALUES(?,?,?,?,?,?,?,?,?,1,?)""",
                        (display_name, item["manual_disabled"], item["lifetime_quota"], item["monthly_quota"],
                         item["reset_day"], item["expires_at"], item["max_devices"], now, now, user_key),
                    )
                    user_id = int(cursor.lastrowid)
                else:
                    user_id = int(row["id"])
                    self.db.connection.execute(
                        """UPDATE users SET manual_disabled=?,lifetime_quota=?,monthly_quota=?,reset_day=?,
                        expires_at=?,max_devices=?,updated_at=? WHERE id=?""",
                        (item["manual_disabled"], item["lifetime_quota"], item["monthly_quota"],
                         item["reset_day"], item["expires_at"], item["max_devices"], now, user_id),
                    )
                self.db.connection.execute("DELETE FROM protocol_permissions WHERE user_id=?", (user_id,))
                self.db.connection.executemany(
                    "INSERT INTO protocol_permissions(user_id,protocol,enabled) VALUES(?,?,?)",
                    ((user_id, protocol, int(item["permissions"].get(protocol, True))) for protocol in PROTOCOLS),
                )
                for device in item["devices"]:
                    device_key = f"{user_key}:device:{device['key']}"
                    keep_devices.add(device_key)
                    existing = self.db.connection.execute(
                        "SELECT * FROM devices WHERE cluster_key=?", (device_key,)
                    ).fetchone()
                    conflict = self.db.connection.execute(
                        "SELECT * FROM devices WHERE (uuid=? OR token=?) AND cluster_key IS NOT ?",
                        (device["uuid"], device["token"], device_key),
                    ).fetchone()
                    if conflict:
                        legacy_prefix = f"{user_key}:device:"
                        same_managed_device = (
                            existing is None
                            and conflict["user_id"] == user_id
                            and str(conflict["cluster_key"] or "").startswith(legacy_prefix)
                            and conflict["uuid"] == device["uuid"]
                            and conflict["token"] == device["token"]
                        )
                        if not same_managed_device:
                            raise AgentError("主 VPS 设备凭据与子 VPS 本地设备冲突")
                        self.db.connection.execute(
                            "UPDATE devices SET cluster_key=? WHERE id=?", (device_key, conflict["id"])
                        )
                        existing = conflict
                    values = (
                        user_id, device["name"], device["uuid"], device["password"],
                        device["ss_password"], device["token"], device["enabled"], now, device_key,
                    )
                    if existing:
                        self.db.connection.execute(
                            """UPDATE devices SET user_id=?,name=?,uuid=?,password=?,ss_password=?,token=?,
                            enabled=?,updated_at=?,cluster_key=? WHERE id=?""", (*values, existing["id"]),
                        )
                    else:
                        self.db.connection.execute(
                            """INSERT INTO devices(user_id,name,uuid,password,ss_password,token,enabled,
                            created_at,updated_at,cluster_key) VALUES(?,?,?,?,?,?,?,?,?,?)""",
                            (*values[:7], now, now, device_key),
                        )
            stale_devices = self.db.connection.execute(
                "SELECT token,cluster_key FROM devices WHERE cluster_key LIKE ?", (prefix + "%",)
            ).fetchall()
            for row in stale_devices:
                if row["cluster_key"] not in keep_devices:
                    self.db.connection.execute("DELETE FROM devices WHERE cluster_key=?", (row["cluster_key"],))
                    shutil.rmtree(self.generated / row["token"], ignore_errors=True)
            stale_users = self.db.connection.execute(
                "SELECT cluster_key FROM users WHERE cluster_managed=1 AND cluster_key LIKE ?", (prefix + "%",)
            ).fetchall()
            for row in stale_users:
                if row["cluster_key"] not in keep_users:
                    self.db.connection.execute("DELETE FROM users WHERE cluster_key=?", (row["cluster_key"],))
            self.db.audit("cluster.users.import", origin, f"users={len(users)}")
        self.backup_database()
        self.render_all_subscriptions()
        return {"users": len(users), "devices": len(keep_devices)}

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

    def cluster_usage_for_user(self, user: sqlite3.Row) -> tuple[int, int]:
        database = self.root / "modules" / "cluster" / "data" / "cluster.db"
        config_path = self.root / "modules" / "cluster" / "config.json"
        if not database.exists() or not config_path.exists():
            return 0, 0
        devices = [
            row["uuid"] for row in self.db.connection.execute(
                "SELECT uuid FROM devices WHERE user_id=?", (user["id"],)
            )
        ]
        if not devices:
            return 0, 0
        try:
            config = json.loads(config_path.read_text(encoding="utf-8"))
            connection = sqlite3.connect(f"file:{database}?mode=ro", uri=True, timeout=2)
            connection.row_factory = sqlite3.Row
            epoch = self.month_period(int(user["reset_day"]))
            if config.get("role") == "master":
                placeholders = ",".join("?" for _ in devices)
                row = connection.execute(
                    f"""SELECT COALESCE(SUM(uplink+downlink),0) lifetime,
                    COALESCE(SUM(month_uplink+month_downlink),0) monthly FROM usage_reports
                    WHERE epoch=? AND device_uuid IN ({placeholders})""",
                    (epoch, *devices),
                ).fetchone()
                return int(row["lifetime"]), int(row["monthly"])
            lifetime = monthly = 0
            for device_uuid in devices:
                row = connection.execute(
                    "SELECT value FROM settings WHERE key=?",
                    (f"usage-sent:{device_uuid}:{epoch}",),
                ).fetchone()
                if row:
                    state = json.loads(row["value"])
                    lifetime += int(state.get("global_total", 0))
                    monthly += int(state.get("global_month", 0))
            return lifetime, monthly
        except (OSError, sqlite3.Error, json.JSONDecodeError, ValueError):
            return 0, 0
        finally:
            if "connection" in locals():
                connection.close()

    def effective_user(self, user: sqlite3.Row) -> tuple[bool, str]:
        if user["manual_disabled"]:
            return False, "管理员停用"
        if user["expires_at"] and utc_now() >= user["expires_at"]:
            return False, "已到期"
        lifetime, monthly = self.usage_for_user(user["id"])
        cluster_lifetime, cluster_monthly = self.cluster_usage_for_user(user)
        lifetime = max(lifetime, cluster_lifetime)
        monthly = max(monthly, cluster_monthly)
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

    def reconcile_visit(self, validate: bool = True) -> dict[str, bool]:
        if self.multiuser_enabled():
            return self.reconcile(validate=validate)
        if not self.db.connection.execute("SELECT 1 FROM devices LIMIT 1").fetchone():
            self.initialize_visit()
        with FileLock(self.lock_path):
            devices = self.active_devices()
            self.generated.mkdir(parents=True, exist_ok=True)
            changed = {"xray": False, "singbox": False}
            pending: list[tuple[Path, dict[str, Any], str]] = []
            temporary: list[tuple[Path, Path, str]] = []
            replaced: list[tuple[Path, Path]] = []
            connection = self.db.connection
            connection.execute("SAVEPOINT visit_reconcile")
            try:
                for core, filename, updater in (
                    ("xray", "xr.json", self._reconcile_visit_xray),
                    ("singbox", "sb.json", self._reconcile_visit_singbox),
                ):
                    target = self.root / filename
                    if not target.exists():
                        continue
                    original = json.loads(target.read_text(encoding="utf-8"))
                    updated = updater(copy.deepcopy(original), devices)
                    if updated != original:
                        pending.append((target, updated, core))
                        changed[core] = True
                for target, payload, core in pending:
                    temp = target.with_name(
                        f".{target.stem}.visit-monitor.{os.getpid()}{target.suffix}"
                    )
                    atomic_write(temp, json.dumps(payload, ensure_ascii=False, indent=2) + "\n")
                    temporary.append((target, temp, core))
                if validate:
                    for _, temp, core in temporary:
                        self._validate_core(core, temp)
                for target, temp, _ in temporary:
                    previous = self.generated / f"previous-visit-{target.name}"
                    shutil.copy2(target, previous)
                    os.replace(temp, target)
                    replaced.append((target, previous))
                connection.execute("RELEASE SAVEPOINT visit_reconcile")
            except Exception:
                with contextlib.suppress(sqlite3.Error):
                    connection.execute("ROLLBACK TO SAVEPOINT visit_reconcile")
                    connection.execute("RELEASE SAVEPOINT visit_reconcile")
                for target, previous in reversed(replaced):
                    if previous.exists():
                        shutil.copy2(previous, target)
                raise
            finally:
                for _, temp, _ in temporary:
                    temp.unlink(missing_ok=True)
            self.db.audit("visit-monitor.reconcile", "cores", json.dumps(changed))
            self.db.connection.commit()
            self.secure_sensitive_files()
            return changed

    def _reconcile_xray(self, data: dict[str, Any], devices: list[dict[str, Any]], config: dict[str, Any]) -> dict[str, Any]:
        monitor = self.visit_monitor_settings()
        if monitor["enabled"]:
            self.data_dir.mkdir(parents=True, exist_ok=True)
        self._configure_visit_log(
            data,
            "xray",
            monitor["enabled"],
            "access",
            {
                "access": monitor["xray_log"],
                "loglevel": "warning",
            },
        )
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
        monitor = self.visit_monitor_settings()
        if monitor["enabled"]:
            self.data_dir.mkdir(parents=True, exist_ok=True)
        self._configure_visit_log(
            data,
            "singbox",
            monitor["enabled"],
            "output",
            {
                "disabled": False,
                "level": "info",
                "output": monitor["singbox_log"],
                "timestamp": True,
            },
        )
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
        if not any(changed.values()):
            return
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

    def apply_visit(self) -> dict[str, bool]:
        if self.multiuser_enabled():
            changed = self.apply()
            self.secure_sensitive_files()
            return changed
        changed = self.reconcile_visit(validate=True)
        try:
            self.restart_cores(changed)
        except AgentError as exc:
            restored: dict[str, bool] = {"xray": False, "singbox": False}
            for core, filename in (("xray", "xr.json"), ("singbox", "sb.json")):
                previous = self.generated / f"previous-visit-{filename}"
                target = self.root / filename
                if changed.get(core) and previous.exists():
                    shutil.copy2(previous, target)
                    restored[core] = True
            rollback_error = ""
            try:
                self.restart_cores(restored)
            except AgentError as rollback_exc:
                rollback_error = f"；回滚配置已写回，但核心重启仍失败：{rollback_exc}"
            raise AgentError(f"监控配置启动失败，已恢复应用前配置：{exc}{rollback_error}") from exc
        self.secure_sensitive_files()
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
            if protocol == "ss" and not config.get("ss_public_port"):
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
            if protocol == "ss" and not config.get("ss_public_port"):
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
            if protocol == "ss" and not config.get("ss_public_port"):
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

    def cluster_subscription_path(self, token: str, filename: str) -> Path | None:
        """Return an enabled cluster profile without making cluster a module dependency."""
        if filename not in {"jhsub.txt", "clmi.yaml", "sbox.json"}:
            return None
        database = self.root / "modules" / "cluster" / "data" / "cluster.db"
        target = self.root / "modules" / "cluster" / "generated" / token / filename
        if not database.exists() or not target.exists() or not re.fullmatch(r"[A-Za-z0-9_-]{16,128}", token):
            return None
        connection: sqlite3.Connection | None = None
        try:
            connection = sqlite3.connect(f"file:{database}?mode=ro", uri=True, timeout=2)
            row = connection.execute(
                "SELECT 1 FROM profiles WHERE token=? AND enabled=1", (token,)
            ).fetchone()
            return target if row else None
        except sqlite3.Error:
            return None
        finally:
            if connection is not None:
                connection.close()

    def refresh_cluster_subscription_async(self, token: str) -> None:
        """Ask the cluster to catch up after returning its cached subscription."""
        script = self.root / "modules" / "cluster" / "lun_cluster.py"
        if not script.is_file():
            sys.stderr.write("cluster subscription refresh unavailable\n")
            return
        token_key = hashlib.sha256(token.encode("utf-8")).hexdigest()
        now = time.monotonic()
        with self._cluster_refresh_lock:
            previous = self._cluster_refresh_started.get(token_key)
            if previous is not None and now - previous < 30:
                return
            try:
                process = subprocess.Popen(
                    [
                        sys.executable,
                        str(script),
                        "--root",
                        str(self.root),
                        "subscription-access",
                        "--token",
                        token,
                    ],
                    stdin=subprocess.DEVNULL,
                    stdout=subprocess.DEVNULL,
                    stderr=subprocess.DEVNULL,
                    start_new_session=True,
                    close_fds=True,
                )
            except OSError:
                sys.stderr.write("cluster subscription refresh could not start\n")
                return
            self._cluster_refresh_started[token_key] = now

        def report_failure() -> None:
            if process.wait() != 0:
                sys.stderr.write("cluster subscription refresh failed\n")

        threading.Thread(target=report_failure, name="cluster-subscription-refresh", daemon=True).start()

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

    def _visit_identity_map(self) -> dict[str, int]:
        identities: dict[str, int] = {}
        rows = self.db.connection.execute(
            "SELECT d.id,d.user_id,d.uuid FROM devices d"
        )
        for row in rows:
            identities[f"lun:u:{row['user_id']}:d:{row['id']}"] = row["id"]
            identities[row["uuid"]] = row["id"]
        return identities

    @staticmethod
    def _visit_suffix_match(domain: str, rule: str) -> bool:
        return domain == rule or domain.endswith(f".{rule}")

    def visit_domain_is_noise(
        self, domain: str, settings: dict[str, Any] | None = None
    ) -> bool:
        settings = settings or self.visit_monitor_settings()
        if any(self._visit_suffix_match(domain, rule) for rule in settings["allowed_domains"]):
            return False
        if any(self._visit_suffix_match(domain, rule) for rule in settings["hidden_domains"]):
            return True
        if settings["filter_mode"] == "off":
            return False
        if domain in VISIT_NOISE_EXACT:
            return True
        return any(self._visit_suffix_match(domain, rule) for rule in VISIT_NOISE_SUFFIXES)

    @staticmethod
    def _visit_suffix_sql(alias: str, rules: Iterable[str]) -> tuple[str, list[str]]:
        clauses = []
        values = []
        for rule in rules:
            clauses.append(f"({alias}.domain=? OR {alias}.domain LIKE ?)")
            values.extend((rule, f"%.{rule}"))
        return " OR ".join(clauses), values

    def _visit_noise_sql(
        self, alias: str, include_noise: bool
    ) -> tuple[str | None, list[str]]:
        if include_noise:
            return None, []
        settings = self.visit_monitor_settings()
        hidden_rules = list(settings["hidden_domains"])
        exact_rules: list[str] = []
        if settings["filter_mode"] == "standard":
            hidden_rules.extend(sorted(VISIT_NOISE_SUFFIXES))
            exact_rules.extend(sorted(VISIT_NOISE_EXACT))
        hidden_sql, hidden_values = self._visit_suffix_sql(alias, dict.fromkeys(hidden_rules))
        if exact_rules:
            exact_sql = " OR ".join(f"{alias}.domain=?" for _ in exact_rules)
            hidden_sql = " OR ".join(part for part in (hidden_sql, exact_sql) if part)
            hidden_values.extend(exact_rules)
        if not hidden_sql:
            return None, []
        allowed_sql, allowed_values = self._visit_suffix_sql(alias, settings["allowed_domains"])
        if allowed_sql:
            return f"(({allowed_sql}) OR NOT ({hidden_sql}))", [*allowed_values, *hidden_values]
        return f"NOT ({hidden_sql})", hidden_values

    @staticmethod
    def _visit_target(value: str) -> tuple[str, int] | None:
        target = value.strip().strip("\"'")
        if target.startswith("["):
            end = target.find("]")
            if end < 1 or end + 2 > len(target) or target[end + 1] != ":":
                return None
            host, raw_port = target[1:end], target[end + 2:]
        else:
            host, separator, raw_port = target.rpartition(":")
            if not separator:
                return None
        if not raw_port.isdigit() or not 1 <= int(raw_port) <= 65535:
            return None
        host = host.rstrip(".").lower()
        try:
            ipaddress.ip_address(host)
            return None
        except ValueError:
            pass
        try:
            host = host.encode("idna").decode("ascii")
        except UnicodeError:
            return None
        if len(host) > 253 or "." not in host:
            return None
        labels = host.split(".")
        if any(
            not label or len(label) > 63 or not re.fullmatch(r"[a-z0-9](?:[a-z0-9_-]*[a-z0-9])?", label)
            for label in labels
        ):
            return None
        return host, int(raw_port)

    @staticmethod
    def _visit_line_timestamp(core: str, line: str) -> int | None:
        local_zone = dt.datetime.now().astimezone().tzinfo or dt.timezone.utc
        if core == "xray":
            match = re.match(r"(\d{4}/\d{2}/\d{2} \d{2}:\d{2}:\d{2}(?:\.\d+)?)", line)
            if not match:
                return None
            raw = match.group(1)
            fmt = "%Y/%m/%d %H:%M:%S.%f" if "." in raw else "%Y/%m/%d %H:%M:%S"
            with contextlib.suppress(ValueError, OverflowError):
                parsed = dt.datetime.strptime(raw, fmt).replace(tzinfo=local_zone)
                return int(parsed.timestamp())
            return None
        if core != "singbox":
            return None
        prefixed = re.match(
            r"([+-]\d{4})\s+(\d{4}-\d{2}-\d{2}[ T]\d{2}:\d{2}:\d{2}(?:\.\d+)?)",
            line,
        )
        if prefixed:
            with contextlib.suppress(ValueError, OverflowError):
                zone = dt.datetime.strptime(prefixed.group(1), "%z").tzinfo
                parsed = dt.datetime.fromisoformat(prefixed.group(2)).replace(tzinfo=zone)
                return int(parsed.timestamp())
        match = re.match(
            r"(\d{4}-\d{2}-\d{2}[ T]\d{2}:\d{2}:\d{2}(?:\.\d+)?(?:Z|[+-]\d{2}:?\d{2})?)",
            line,
        )
        if not match:
            return None
        raw = match.group(1).replace("Z", "+00:00")
        if re.search(r"[+-]\d{4}$", raw):
            raw = f"{raw[:-5]}{raw[-5:-2]}:{raw[-2:]}"
        with contextlib.suppress(ValueError, OverflowError):
            parsed = dt.datetime.fromisoformat(raw)
            if parsed.tzinfo is None:
                parsed = parsed.replace(tzinfo=local_zone)
            return int(parsed.timestamp())
        return None

    @classmethod
    def parse_visit_line(cls, core: str, line: str) -> dict[str, Any] | None:
        if core == "xray":
            match = re.search(r"\baccepted\s+(tcp|udp):(\[[^\]]+\]:[0-9]+|\S+)", line)
            identity = re.search(r"\bemail:\s*(\S+)", line)
            if not match or not identity:
                return None
            target = cls._visit_target(match.group(2))
            if not target:
                return None
            route = re.search(r"\[([^\]]+?)\s+(?:->|>>)\s+[^\]]+\]", line)
            inbound = route.group(1).strip() if route else "xray"
            network = match.group(1)
            user_identity = identity.group(1)
        elif core == "singbox":
            match = re.search(
                r"inbound/[^\s:]+\[([^\]]+)\]:\s+"
                r"(?:\[([^\]]+)\]\s+)?inbound\s+"
                r"(?:(packet|multiplex)\s+)?connection\s+to\s+(\[[^\]]+\]:[0-9]+|\S+)",
                line,
            )
            if not match:
                return None
            target = cls._visit_target(match.group(4))
            if not target:
                return None
            inbound = match.group(1)
            network = "udp" if match.group(3) == "packet" else "tcp"
            user_identity = match.group(2) or ""
        else:
            return None
        return {
            "identity": user_identity,
            "core": core,
            "network": network,
            "inbound": inbound[:80],
            "domain": target[0],
            "port": target[1],
            "occurred_at": cls._visit_line_timestamp(core, line),
        }

    def _read_visit_chunk(self, core: str, path: Path) -> tuple[list[str], int, int, int] | None:
        try:
            stat = path.stat()
            os.chmod(path, 0o600)
        except OSError:
            return None
        try:
            inode = int(self.db.setting(f"visit_{core}_inode", "0"))
            offset = int(self.db.setting(f"visit_{core}_offset", "0"))
        except ValueError:
            inode, offset = 0, 0
        if inode != stat.st_ino or offset < 0 or stat.st_size < offset:
            offset = 0
        try:
            with path.open("rb") as handle:
                handle.seek(offset)
                payload = handle.read(VISIT_READ_MAX_BYTES)
        except OSError:
            return None
        new_offset = offset + len(payload)
        if payload and not payload.endswith(b"\n"):
            boundary = payload.rfind(b"\n")
            if boundary >= 0:
                payload = payload[:boundary + 1]
                new_offset = offset + boundary + 1
            elif len(payload) >= VISIT_READ_MAX_BYTES:
                # Skip one malformed/hostile oversized line instead of blocking collection forever.
                payload = b""
            else:
                payload = b""
                new_offset = offset
        lines = payload.decode("utf-8", "replace").splitlines()
        return lines, stat.st_ino, new_offset, stat.st_size

    def _prune_visit_history(self, settings: dict[str, Any], now: int) -> None:
        detail_cutoff = now - settings["detail_days"] * 86400
        summary_cutoff = (
            dt.datetime.fromtimestamp(now, dt.timezone.utc)
            - dt.timedelta(days=settings["summary_days"] - 1)
        ).strftime("%Y-%m-%d")
        self.db.connection.execute("DELETE FROM visit_events WHERE occurred_at<?", (detail_cutoff,))
        self.db.connection.execute("DELETE FROM visit_daily WHERE day<?", (summary_cutoff,))
        event_count = self.db.connection.execute("SELECT COUNT(*) FROM visit_events").fetchone()[0]
        if event_count > settings["event_limit"]:
            self.db.connection.execute(
                "DELETE FROM visit_events WHERE id IN ("
                "SELECT id FROM visit_events ORDER BY occurred_at DESC,id DESC LIMIT -1 OFFSET ?)",
                (settings["event_limit"],),
            )
        summary_count = self.db.connection.execute("SELECT COUNT(*) FROM visit_daily").fetchone()[0]
        if summary_count > settings["summary_limit"]:
            self.db.connection.execute(
                "DELETE FROM visit_daily WHERE rowid IN ("
                "SELECT rowid FROM visit_daily ORDER BY day DESC,last_seen DESC LIMIT -1 OFFSET ?)",
                (settings["summary_limit"],),
            )

    def collect_visit_logs(self) -> int:
        with FileLock(self.lock_path):
            return self._collect_visit_logs_unlocked()

    def _collect_visit_logs_unlocked(self) -> int:
        settings = self.visit_monitor_settings()
        if not settings["enabled"]:
            return 0
        identities = self._visit_identity_map()
        device_ids = set(identities.values())
        local_device = (
            next(iter(device_ids))
            if len(device_ids) == 1 and not self.multiuser_enabled()
            else None
        )
        now = utc_now()
        pending: list[dict[str, Any]] = []
        cursors: list[tuple[str, Path, int, int, int]] = []
        for core, path in self.visit_log_paths().items():
            chunk = self._read_visit_chunk(core, path)
            if not chunk:
                continue
            lines, inode, offset, size = chunk
            for line in lines:
                event = self.parse_visit_line(core, line)
                if not event:
                    continue
                device_id = identities.get(event["identity"])
                if device_id is None and not event["identity"]:
                    device_id = local_device
                if device_id is not None:
                    event["device_id"] = device_id
                    pending.append(event)
            cursors.append((core, path, inode, offset, size))
        with self.db.connection:
            for event in pending:
                occurred_at = event.get("occurred_at") or now
                if occurred_at < 1 or occurred_at > now + 86400:
                    occurred_at = now
                day = dt.datetime.fromtimestamp(occurred_at, dt.timezone.utc).strftime("%Y-%m-%d")
                values = (
                    occurred_at, event["device_id"], event["core"], event["network"],
                    event["inbound"], event["domain"], event["port"],
                )
                self.db.connection.execute(
                    "INSERT INTO visit_events(occurred_at,device_id,core,network,inbound,domain,port) "
                    "VALUES(?,?,?,?,?,?,?)",
                    values,
                )
                self.db.connection.execute(
                    "INSERT INTO visit_daily(day,device_id,core,network,inbound,domain,port,"
                    "connections,first_seen,last_seen) VALUES(?,?,?,?,?,?,?,?,?,?) "
                    "ON CONFLICT(day,device_id,core,network,inbound,domain,port) DO UPDATE SET "
                    "connections=connections+1,"
                    "first_seen=MIN(first_seen,excluded.first_seen),"
                    "last_seen=MAX(last_seen,excluded.last_seen)",
                    (day, *values[1:], 1, occurred_at, occurred_at),
                )
            for core, _, inode, offset, _ in cursors:
                self.db.set_setting(f"visit_{core}_inode", inode)
                self.db.set_setting(f"visit_{core}_offset", offset)
            self.db.set_setting("visit_last_collect", now)
            self._prune_visit_history(settings, now)
        for core, path, inode, offset, size in cursors:
            if size <= settings["log_max_bytes"] or offset < size:
                continue
            try:
                with path.open("r+b") as handle:
                    current = os.fstat(handle.fileno())
                    if current.st_ino != inode or current.st_size != offset:
                        continue
                    handle.truncate(0)
                with self.db.connection:
                    self.db.set_setting(f"visit_{core}_inode", inode)
                    self.db.set_setting(f"visit_{core}_offset", 0)
            except OSError:
                pass
        self.secure_sensitive_files()
        return len(pending)

    def visit_status(self) -> dict[str, Any]:
        settings = self.visit_monitor_settings()
        settings.update({
            "mode": "multiuser" if self.multiuser_enabled() else "local",
            "identities": self.db.connection.execute("SELECT COUNT(*) FROM devices").fetchone()[0],
            "events": self.db.connection.execute("SELECT COUNT(*) FROM visit_events").fetchone()[0],
            "summaries": self.db.connection.execute("SELECT COUNT(*) FROM visit_daily").fetchone()[0],
            "last_collect": int(self.db.setting("visit_last_collect", "0") or 0),
        })
        for core, path in self.visit_log_paths().items():
            try:
                settings[f"{core}_log_bytes"] = path.stat().st_size
            except OSError:
                settings[f"{core}_log_bytes"] = 0
        return settings

    @staticmethod
    def _visit_filters(
        days: int, user_id: int | None, device_id: int | None, domain: str | None
    ) -> tuple[list[str], list[Any]]:
        clauses = ["e.occurred_at>=?"]
        values: list[Any] = [utc_now() - max(1, days) * 86400]
        if user_id:
            clauses.append("u.id=?")
            values.append(user_id)
        if device_id:
            clauses.append("d.id=?")
            values.append(device_id)
        if domain:
            clauses.append("e.domain LIKE ?")
            values.append(f"%{domain.strip().lower()}%")
        return clauses, values

    def _visit_display_rows(self, rows: Iterable[sqlite3.Row]) -> list[dict[str, Any]]:
        result = [dict(row) for row in rows]
        if not self.multiuser_enabled():
            for row in result:
                if row.get("user_name") == "legacy-admin":
                    row["user_name"] = "本机用户"
                if row.get("device_name") == "legacy-device":
                    row["device_name"] = "本机设备"
        return result

    def visit_recent(
        self, days: int, limit: int, user_id: int | None = None,
        device_id: int | None = None, domain: str | None = None,
    ) -> list[dict[str, Any]]:
        clauses, values = self._visit_filters(days, user_id, device_id, domain)
        values.append(min(max(1, limit), 500))
        rows = self.db.connection.execute(
            "SELECT e.occurred_at,u.id user_id,u.name user_name,d.id device_id,d.name device_name,"
            "e.core,e.network,e.inbound,e.domain,e.port FROM visit_events e "
            "JOIN devices d ON d.id=e.device_id JOIN users u ON u.id=d.user_id WHERE "
            + " AND ".join(clauses)
            + " ORDER BY e.occurred_at DESC,e.id DESC LIMIT ?",
            values,
        ).fetchall()
        return self._visit_display_rows(rows)

    def visit_activity(
        self, days: int, limit: int, user_id: int | None = None,
        device_id: int | None = None, domain: str | None = None,
        include_noise: bool = False,
    ) -> list[dict[str, Any]]:
        clauses, values = self._visit_filters(days, user_id, device_id, domain)
        noise_clause, noise_values = self._visit_noise_sql("e", include_noise)
        if noise_clause:
            clauses.append(noise_clause)
            values.extend(noise_values)
        settings = self.visit_monitor_settings()
        values.extend((settings["merge_minutes"] * 60, min(max(1, limit), 500)))
        rows = self.db.connection.execute(
            "WITH ordered AS ("
            "SELECT e.*,LAG(e.occurred_at) OVER ("
            "PARTITION BY e.device_id,e.domain,e.port ORDER BY e.occurred_at,e.id"
            ") previous_at FROM visit_events e "
            "JOIN devices d ON d.id=e.device_id JOIN users u ON u.id=d.user_id WHERE "
            + " AND ".join(clauses)
            + "),marked AS ("
            "SELECT ordered.*,CASE WHEN previous_at IS NULL OR occurred_at-previous_at>? "
            "THEN 1 ELSE 0 END new_activity FROM ordered"
            "),sessionized AS ("
            "SELECT marked.*,SUM(new_activity) OVER ("
            "PARTITION BY device_id,domain,port ORDER BY occurred_at,id ROWS UNBOUNDED PRECEDING"
            ") activity_id FROM marked"
            ") SELECT MIN(s.occurred_at) first_seen,MAX(s.occurred_at) last_seen,"
            "u.id user_id,u.name user_name,d.id device_id,d.name device_name,"
            "s.domain,s.port,COUNT(*) connections,"
            "MAX(CASE WHEN s.network='tcp' THEN 1 ELSE 0 END) has_tcp,"
            "MAX(CASE WHEN s.network='udp' THEN 1 ELSE 0 END) has_udp,"
            "COUNT(DISTINCT s.inbound) inbounds FROM sessionized s "
            "JOIN devices d ON d.id=s.device_id JOIN users u ON u.id=d.user_id "
            "GROUP BY s.device_id,s.domain,s.port,s.activity_id "
            "ORDER BY last_seen DESC LIMIT ?",
            values,
        ).fetchall()
        return self._visit_display_rows(rows)

    def visit_top(
        self, days: int, limit: int, group: str = "domain",
        user_id: int | None = None, device_id: int | None = None,
        include_noise: bool = True,
    ) -> list[dict[str, Any]]:
        cutoff = (
            dt.datetime.now(dt.timezone.utc) - dt.timedelta(days=max(1, days) - 1)
        ).strftime("%Y-%m-%d")
        clauses = ["v.day>=?"]
        values: list[Any] = [cutoff]
        if user_id:
            clauses.append("u.id=?")
            values.append(user_id)
        if device_id:
            clauses.append("d.id=?")
            values.append(device_id)
        noise_clause, noise_values = self._visit_noise_sql("v", include_noise)
        if noise_clause:
            clauses.append(noise_clause)
            values.extend(noise_values)
        values.append(min(max(1, limit), 500))
        if group == "user":
            select = (
                "u.id user_id,u.name user_name,COUNT(DISTINCT v.domain) domains,"
                "SUM(v.connections) connections,MAX(v.last_seen) last_seen"
            )
            grouping = "u.id,u.name"
        else:
            select = (
                "v.domain,v.port,COUNT(DISTINCT u.id) users,"
                "SUM(v.connections) connections,MAX(v.last_seen) last_seen"
            )
            grouping = "v.domain,v.port"
        rows = self.db.connection.execute(
            f"SELECT {select} FROM visit_daily v "
            "JOIN devices d ON d.id=v.device_id JOIN users u ON u.id=d.user_id WHERE "
            + " AND ".join(clauses)
            + f" GROUP BY {grouping} ORDER BY connections DESC,last_seen DESC LIMIT ?",
            values,
        ).fetchall()
        return self._visit_display_rows(rows)

    def clear_visit_history(self, confirmation: str) -> None:
        if confirmation != "CLEAR":
            raise AgentError("清空访问记录需要输入 CLEAR")
        with FileLock(self.lock_path):
            with self.db.connection:
                self.db.connection.execute("DELETE FROM visit_events")
                self.db.connection.execute("DELETE FROM visit_daily")
                for core in self.visit_log_paths():
                    self.db.set_setting(f"visit_{core}_inode", 0)
                    self.db.set_setting(f"visit_{core}_offset", 0)
                self.db.set_setting("visit_last_collect", 0)
                self.db.audit("visit-monitor.clear", "module")
            for path in self.visit_log_paths().values():
                try:
                    with path.open("wb"):
                        pass
                    os.chmod(path, 0o600)
                except OSError:
                    pass
        self.secure_sensitive_files()

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
        self.secure_sensitive_files()
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
                self.db.migrate()
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
            "visit_monitor": self.visit_monitor_settings()["enabled"],
            "visit_events": self.db.connection.execute("SELECT COUNT(*) FROM visit_events").fetchone()[0],
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
        cluster_target = agent.cluster_subscription_path(token, filename)
        if cluster_target is not None:
            payload = cluster_target.read_bytes()
            content_type = {"jhsub.txt": "text/plain", "clmi.yaml": "text/yaml", "sbox.json": "application/json"}[filename]
            self.send_response(200)
            self.send_header("Content-Type", f"{content_type}; charset=utf-8")
            self.send_header("Content-Length", str(len(payload)))
            self.send_header("Cache-Control", "no-store")
            self.end_headers()
            if send_body:
                self.wfile.write(payload)
                agent.refresh_cluster_subscription_async(token)
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
    subscription_only = bool(config.get("subscription_only"))
    if not config.get("enabled") and not subscription_only:
        raise AgentError("多用户模块已停用")
    agent.sync_legacy_subscription_state()
    config = agent.load_config()
    if not subscription_only:
        agent.reconcile(validate=False)
    else:
        agent.render_all_subscriptions()
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

    if not subscription_only:
        threading.Thread(target=maintenance_loop, name="maintenance", daemon=True).start()
    try:
        server.serve_forever(poll_interval=0.5)
    finally:
        server.server_close()
        if legacy_server:
            legacy_server.server_close()


def serve_visits(agent: Agent) -> None:
    if not agent.visit_monitor_settings()["enabled"]:
        raise AgentError("网站访问监控尚未启用")
    interval = 30
    if agent.config_path.exists():
        with contextlib.suppress(OSError, ValueError, json.JSONDecodeError):
            interval = max(15, int(agent.load_config().get("poll_interval", 30)))
    stopping = threading.Event()

    def stop(*_: Any) -> None:
        stopping.set()

    signal.signal(signal.SIGTERM, stop)
    signal.signal(signal.SIGINT, stop)
    while not stopping.is_set() and agent.visit_monitor_settings()["enabled"]:
        try:
            agent.collect_visit_logs()
        except Exception as exc:
            sys.stderr.write(f"visit collection failed: {exc}\n")
        if stopping.wait(interval):
            break


def print_subscription_links(device: sqlite3.Row, config: dict[str, Any]) -> None:
    host = config.get("public_host") or "SERVER"
    port = config.get("public_port") or config.get("port")
    scheme = config.get("scheme", "http")
    for filename, label in (("clmi.yaml", "Clash/Mihomo"), ("sbox.json", "Sing-box"), ("jhsub.txt", "聚合")):
        print(f"{label}订阅地址：{scheme}://{host}:{port}/{device['token']}/{filename}")


def print_device(device: sqlite3.Row, config: dict[str, Any]) -> None:
    print(f"设备 ID：{device['id']}")
    print(f"设备名称：{device['name']}")
    print(f"UUID：{device['uuid']}")
    print(f"通用密码：{device['password']}")
    print(f"SS-2022 用户密钥：{device['ss_password']}")
    print(f"订阅 token：{device['token']}")
    print_subscription_links(device, config)


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

    subscription_only = sub.add_parser("init-subscription-only")
    subscription_only.add_argument("--legacy-uuid")
    subscription_only.add_argument("--legacy-token")
    subscription_only.add_argument("--bind", default="::")
    subscription_only.add_argument("--port", type=int, required=True)
    subscription_only.add_argument("--public-port", type=int, default=0)
    subscription_only.add_argument("--legacy-http-port", type=int, default=0)
    subscription_only.add_argument("--legacy-http-public-port", type=int, default=0)
    subscription_only.add_argument("--scheme", choices=("http", "https"), required=True)
    subscription_only.add_argument("--public-host", required=True)
    subscription_only.add_argument("--certificate")
    subscription_only.add_argument("--private-key")

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
    sub.add_parser("show-local-subscription")
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
    subscription_port = sub.add_parser("set-subscription-port")
    subscription_port.add_argument("--port", type=int, required=True)
    subscription_port.add_argument("--public-port", type=int, required=True)
    sub.add_parser("sync-subscription-state")
    cluster_export = sub.add_parser("cluster-export")
    cluster_export.add_argument("--user-ids", default="")
    cluster_import = sub.add_parser("cluster-import")
    cluster_import.add_argument("--path", required=True)
    cluster_import.add_argument("--origin", required=True)
    sub.add_parser("visit-init")
    sub.add_parser("visit-apply")
    sub.add_parser("visit-serve")
    visit_config = sub.add_parser("visit-config")
    visit_config.add_argument("--enabled", choices=("yes", "no"), required=True)
    visit_config.add_argument("--detail-days", type=int)
    visit_config.add_argument("--summary-days", type=int)
    sub.add_parser("visit-status")
    sub.add_parser("visit-collect")
    visit_recent = sub.add_parser("visit-recent")
    visit_recent.add_argument("--days", type=int, default=1)
    visit_recent.add_argument("--limit", type=int, default=50)
    visit_recent.add_argument("--user-id", type=int)
    visit_recent.add_argument("--device-id", type=int)
    visit_recent.add_argument("--domain")
    visit_recent.add_argument("--view", choices=("raw", "smart"), default="raw")
    visit_recent.add_argument("--noise", choices=("auto", "show"), default="show")
    visit_top = sub.add_parser("visit-top")
    visit_top.add_argument("--days", type=int, default=7)
    visit_top.add_argument("--limit", type=int, default=30)
    visit_top.add_argument("--group", choices=("domain", "user"), default="domain")
    visit_top.add_argument("--user-id", type=int)
    visit_top.add_argument("--device-id", type=int)
    visit_top.add_argument("--noise", choices=("auto", "show"), default="show")
    visit_filter = sub.add_parser("visit-filter")
    visit_filter.add_argument("--mode", choices=("standard", "off"))
    visit_filter.add_argument("--merge-minutes", type=int)
    visit_filter.add_argument(
        "--action", choices=("add-hide", "remove-hide", "add-show", "remove-show", "reset")
    )
    visit_filter.add_argument("--domain")
    visit_clear = sub.add_parser("visit-clear")
    visit_clear.add_argument("--confirm", required=True)
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
        elif args.command == "init-subscription-only":
            result = agent.initialize_subscription_only(args)
            print("订阅专用服务初始化完成。")
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
        elif args.command == "show-local-subscription":
            device = agent.local_subscription_device()
            result = {"device_id": device["id"]}
            if not args.json:
                print_subscription_links(device, agent.load_config())
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
                    "visit_monitor": "网站访问监控",
                    "visit_events": "访问明细记录数",
                }
                for key, value in result.items():
                    if isinstance(value, bool):
                        if key in {"enabled", "visit_monitor"}:
                            value = "已启用" if value else "已停用"
                        elif key in {"singbox_v2ray_api", "singbox_stats_helper"}:
                            value = "已安装" if value else "可选组件未安装（不影响基础多用户）"
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
        elif args.command == "set-subscription-port":
            result = agent.set_subscription_port(args.port, args.public_port)
            print(
                f"多用户订阅端口已更新：内网 {result['port']} / 公网 {result['public_port']}。"
            )
        elif args.command == "sync-subscription-state":
            result = agent.sync_legacy_subscription_state()
            print(
                f"订阅状态已同步：设备 {result['device_id']}，"
                f"内网 {result['port']} / 公网 {result['public_port']}。"
            )
        elif args.command == "cluster-export":
            user_ids = None
            if args.user_ids.strip():
                try:
                    user_ids = [int(item) for item in re.split(r"[,\s]+", args.user_ids.strip())]
                except ValueError as exc:
                    raise AgentError("用户 ID 列表无效") from exc
            result = agent.export_cluster_users(user_ids)
            if not args.json:
                print(f"已导出 {len(result['users'])} 个主 VPS 用户。")
        elif args.command == "cluster-import":
            try:
                bundle = json.loads(Path(args.path).read_text(encoding="utf-8"))
            except (OSError, json.JSONDecodeError) as exc:
                raise AgentError(f"主 VPS 用户数据无法读取：{exc}") from exc
            if not isinstance(bundle, dict):
                raise AgentError("主 VPS 用户数据必须是 JSON 对象")
            result = agent.import_cluster_users(bundle, args.origin)
            print(f"已同步 {result['users']} 个用户 / {result['devices']} 台设备。")
        elif args.command == "visit-init":
            result = agent.initialize_visit()
            print("本机网站监控身份已初始化。")
        elif args.command == "visit-apply":
            result = agent.apply_visit()
            print(f"网站访问监控配置已校验并应用：{result}")
        elif args.command == "visit-config":
            current = agent.visit_monitor_settings()
            result = agent.set_visit_monitor(
                args.enabled == "yes",
                args.detail_days if args.detail_days is not None else current["detail_days"],
                args.summary_days if args.summary_days is not None else current["summary_days"],
            )
            print("网站访问监控设置已保存。")
        elif args.command == "visit-status":
            result = agent.visit_status()
            if not args.json:
                print(f"监控状态：{'已启用' if result['enabled'] else '未启用'}")
                print(
                    "运行模式："
                    + ("多用户归属" if result["mode"] == "multiuser" else "本机用户 / 本机设备")
                )
                print(
                    f"保留策略：逐条明细 {result['detail_days']} 天；"
                    f"每日汇总 {result['summary_days']} 天"
                )
                if result["summary_days"] > result["detail_days"]:
                    print(
                        f"说明：第 {result['detail_days'] + 1}-{result['summary_days']} 天"
                        "仅保留每日访问次数，不保留逐条明细。"
                    )
                print(f"数据库：明细 {result['events']} 条 / 汇总 {result['summaries']} 条")
                print(
                    "原始日志：Xray {} / Sing-box {}".format(
                        format_storage(result["xray_log_bytes"]),
                        format_storage(result["singbox_log_bytes"]),
                    )
                )
                print(
                    "最后采集："
                    + (
                        iso_time(result["last_collect"])
                        if result["last_collect"] else "尚未采集"
                    )
                )
                print_visit_filter_status(result)
        elif args.command == "visit-collect":
            collected = agent.collect_visit_logs()
            result = {"collected": collected}
            print(f"本次新增访问记录：{collected} 条")
        elif args.command == "visit-recent":
            if args.view == "smart":
                result = agent.visit_activity(
                    args.days, args.limit, args.user_id, args.device_id, args.domain,
                    include_noise=args.noise == "show",
                )
            else:
                result = agent.visit_recent(
                    args.days, args.limit, args.user_id, args.device_id, args.domain
                )
            if not args.json:
                if args.view == "smart":
                    print_visit_activity(result)
                else:
                    print_visit_recent(result)
        elif args.command == "visit-top":
            result = agent.visit_top(
                args.days, args.limit, args.group, args.user_id, args.device_id,
                include_noise=args.noise == "show",
            )
            if not args.json:
                print_visit_top(result, args.group)
        elif args.command == "visit-filter":
            result = agent.visit_monitor_settings()
            if args.mode is not None or args.merge_minutes is not None:
                result = agent.set_visit_filter(args.mode, args.merge_minutes)
            if args.action == "reset":
                result = agent.reset_visit_filter_rules()
            elif args.action:
                if not args.domain:
                    raise AgentError("该规则操作必须提供 --domain")
                result = agent.update_visit_filter_rule(args.action, args.domain)
            if not args.json:
                print_visit_filter_status(result)
        elif args.command == "visit-clear":
            agent.clear_visit_history(args.confirm)
            result = {"cleared": True}
            print("网站访问记录与原始日志已清空。")
        elif args.command == "serve":
            serve(agent)
        elif args.command == "visit-serve":
            serve_visits(agent)
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
