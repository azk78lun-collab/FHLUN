#!/usr/bin/env python3
"""Lun on-demand Cloudflare edge optimizer 2.0.

The temporary service keeps client and VPS measurements separate.  Only
allow-listed source URLs are fetched, and applying a replacement requires a
server-generated preview digest.
"""

from __future__ import annotations

import argparse
import concurrent.futures
import hashlib
import hmac
import http.client
import ipaddress
import json
import os
import random
import re
import secrets
import socket
import ssl
import statistics
import sys
import threading
import time
import urllib.error
import urllib.request
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
from urllib.parse import urlsplit


VERSION = "2.0.3"
MAX_SOURCE_BYTES = 1024 * 1024
MAX_REQUEST_BYTES = 2 * 1024 * 1024
MAX_CANDIDATES = 4096
MAX_SELECTED = 50
CF_HTTPS_PORTS = (443, 2053, 2083, 2087, 2096, 8443)
DEFAULT_SOURCE_KEY = "bestcf-general"
SOURCES = {
    "bestcf-general": ("BestCF 综合优选", "https://raw.githubusercontent.com/DustinWin/BestCF/bestcf/bestcf-ip.txt"),
    "bestcf-cmcc": ("BestCF 中国移动", "https://raw.githubusercontent.com/DustinWin/BestCF/bestcf/cmcc-ip.txt"),
    "bestcf-cucc": ("BestCF 中国联通", "https://raw.githubusercontent.com/DustinWin/BestCF/bestcf/cucc-ip.txt"),
    "bestcf-ctcc": ("BestCF 中国电信", "https://raw.githubusercontent.com/DustinWin/BestCF/bestcf/ctcc-ip.txt"),
    "cmliu-v4": ("CMLiu Cloudflare IPv4", "https://cf.090227.xyz/ips-v4"),
    "cmliu-v6": ("CMLiu Cloudflare IPv6", "https://cf.090227.xyz/ips-v6"),
    "cmliu-cidr": ("CMLiu CF-CIDR", "https://raw.githubusercontent.com/cmliu/cmliu/main/CF-CIDR.txt"),
    "as13335-v4": ("Cloudflare AS13335 IPv4", "https://raw.githubusercontent.com/ipverse/asn-ip/master/as/13335/ipv4-aggregated.txt"),
    "as13335-v6": ("Cloudflare AS13335 IPv6", "https://raw.githubusercontent.com/ipverse/asn-ip/master/as/13335/ipv6-aggregated.txt"),
    "as209242-v4": ("Cloudflare AS209242 IPv4", "https://raw.githubusercontent.com/ipverse/asn-ip/master/as/209242/ipv4-aggregated.txt"),
    "as209242-v6": ("Cloudflare AS209242 IPv6", "https://raw.githubusercontent.com/ipverse/asn-ip/master/as/209242/ipv6-aggregated.txt"),
}


def _number(value, default=0.0):
    try:
        number = float(value)
    except (TypeError, ValueError):
        return default
    if number != number or number in (float("inf"), float("-inf")):
        return default
    return number


def _bounded(value, default, minimum, maximum, label, integer=False):
    number = _number(value, default)
    if integer:
        number = int(number)
    if number < minimum or number > maximum:
        raise ValueError(f"{label}必须在 {minimum:g}-{maximum:g} 之间")
    return number


def _global_ip(value):
    address = ipaddress.ip_address(value)
    if not address.is_global:
        raise ValueError("只接受公网 IP")
    return address


def _split_endpoint(value):
    value = value.strip()
    if value.startswith("["):
        match = re.fullmatch(r"\[([^]]+)](?::(\d+))?", value)
        if not match:
            raise ValueError("IPv6 地址格式无效")
        return match.group(1), int(match.group(2) or 0)
    if value.count(":") == 1:
        host, port_text = value.rsplit(":", 1)
        if port_text.isdigit():
            return host, int(port_text)
    return value, 0


def _source_label(raw_label, fallback):
    label = (raw_label or fallback or "手动输入").strip()
    return label[:48] or "手动输入"


def _parse_candidate_lines(text, limit=MAX_CANDIDATES, seed=None, default_source="手动输入"):
    """Parse IP, endpoint, CIDR and IP ranges without expanding huge ranges."""
    limit = int(_bounded(limit, 512, 1, MAX_CANDIDATES, "候选数量", True))
    direct = []
    networks = []
    ranges = []
    for raw in text.splitlines():
        line = raw.strip()
        if not line or line.startswith("#"):
            continue
        value, _, raw_label = line.partition("#")
        label = _source_label(raw_label, default_source)
        for value in re.split(r"[\s,，;；]+", value.strip()):
            if not value:
                continue
            try:
                if "/" in value:
                    network = ipaddress.ip_network(value, strict=False)
                    if not network.network_address.is_global:
                        continue
                    networks.append((network, label, 0))
                    continue
                if "-" in value and not value.startswith("["):
                    left, right = value.split("-", 1)
                    start = _global_ip(left.strip())
                    end = _global_ip(right.strip())
                    if start.version != end.version or int(start) > int(end):
                        continue
                    ranges.append((start, end, label, 0))
                    continue
                host, port = _split_endpoint(value)
                address = _global_ip(host)
                if port and not 1 <= port <= 65535:
                    continue
                direct.append((address, label, port))
            except (ValueError, ipaddress.AddressValueError):
                continue
    if not direct and not networks and not ranges:
        raise ValueError("候选内容中没有可用的公网 IP、CIDR 或 IP 区间")

    rng = random.Random(seed) if seed is not None else secrets.SystemRandom()
    rng.shuffle(direct)
    rng.shuffle(networks)
    rng.shuffle(ranges)
    result = []
    seen = set()

    def add(address, label, port):
        normalized = str(address)
        if normalized in seen or len(result) >= limit:
            return
        seen.add(normalized)
        result.append({
            "ip": normalized,
            "ip_type": "IPv6" if address.version == 6 else "IPv4",
            "source": label,
            "port": port,
        })

    for address, label, port in direct:
        add(address, label, port)
    pools = [("network", item) for item in networks] + [("range", item) for item in ranges]
    attempts = 0
    max_attempts = max(limit * 30, len(pools) * 20)
    while pools and len(result) < limit and attempts < max_attempts:
        kind, item = pools[attempts % len(pools)]
        if kind == "network":
            network, label, port = item
            low, high = int(network.network_address), int(network.broadcast_address)
            if network.version == 4 and network.num_addresses > 2:
                low, high = low + 1, high - 1
        else:
            start, end, label, port = item
            low, high = int(start), int(end)
        add(ipaddress.ip_address(rng.randint(low, high)), label, port)
        attempts += 1
    if not result:
        raise ValueError("未能生成候选 IP")
    return result


def _atomic_bytes(path, payload, mode=0o600):
    target = Path(path)
    target.parent.mkdir(parents=True, exist_ok=True)
    temporary = target.with_name(f".{target.name}.tmp.{os.getpid()}.{secrets.token_hex(4)}")
    temporary.write_bytes(payload)
    os.chmod(temporary, mode)
    os.replace(temporary, target)
    os.chmod(target, mode)


def _atomic_json(path, data):
    payload = (json.dumps(data, ensure_ascii=False, indent=2) + "\n").encode("utf-8")
    _atomic_bytes(path, payload)


def _fetch_source(source_key, cache_dir, source_file=None):
    cache_dir = Path(cache_dir)
    cache_dir.mkdir(parents=True, exist_ok=True)
    try:
        os.chmod(cache_dir, 0o700)
    except OSError:
        pass
    if source_file:
        text = Path(source_file).read_text(encoding="utf-8")
        if len(text.encode("utf-8")) > MAX_SOURCE_BYTES:
            raise ValueError("候选文件超过 1 MiB，已拒绝")
        return text, {"key": "local-file", "name": "本地候选文件", "url": "", "cached": False, "fetched_at": int(time.time())}
    if source_key not in SOURCES:
        raise ValueError("候选库不在 Lun 允许列表中")
    name, url = SOURCES[source_key]
    cache_file = cache_dir / f"{source_key}.txt"
    meta_file = cache_dir / f"{source_key}.json"
    request = urllib.request.Request(url, headers={
        "User-Agent": f"Lun-CDN-Optimizer/{VERSION}",
        "Accept": "text/plain",
        "Cache-Control": "no-cache",
        "Pragma": "no-cache",
    })
    try:
        with urllib.request.urlopen(request, timeout=20) as response:
            content = response.read(MAX_SOURCE_BYTES + 1)
        if len(content) > MAX_SOURCE_BYTES:
            raise ValueError("候选库超过 1 MiB，已拒绝")
        text = content.decode("utf-8", errors="replace")
        fetched_at = int(time.time())
        _atomic_bytes(cache_file, text.encode("utf-8"))
        _atomic_json(meta_file, {"fetched_at": fetched_at, "url": url})
        return text, {"key": source_key, "name": name, "url": url, "cached": False, "fetched_at": fetched_at}
    except (OSError, ValueError, urllib.error.URLError):
        if not cache_file.is_file():
            raise
        fetched_at = int(cache_file.stat().st_mtime)
        try:
            fetched_at = int(json.loads(meta_file.read_text(encoding="utf-8")).get("fetched_at", fetched_at))
        except (OSError, ValueError, json.JSONDecodeError):
            pass
        return cache_file.read_text(encoding="utf-8"), {
            "key": source_key, "name": name, "url": url, "cached": True, "fetched_at": fetched_at
        }


def load_candidates(source_key=DEFAULT_SOURCE_KEY, limit=512, cache_dir=None, source_file=None, seed=None):
    cache_dir = cache_dir or str(Path.home() / "lun" / "modules" / "cdnopt" / "cache")
    text, metadata = _fetch_source(source_key, cache_dir, source_file)
    return _parse_candidate_lines(text, limit, seed, metadata["name"]), metadata


def _read_current_ips(path):
    if not path or not Path(path).is_file():
        return []
    values = []
    for token in re.split(r"[\s,]+", Path(path).read_text(encoding="utf-8", errors="replace")):
        token = token.strip()
        if not token:
            continue
        try:
            host, _ = _split_endpoint(token.split("#", 1)[0])
            normalized = str(ipaddress.ip_address(host))
        except ValueError:
            continue
        if normalized not in values:
            values.append(normalized)
    return values


def _validate_measurements(measurements, candidates, path_name):
    allowed = {item["ip"]: item for item in candidates}
    accepted = []
    seen = set()
    for raw in measurements if isinstance(measurements, list) else []:
        if not isinstance(raw, dict):
            continue
        try:
            address = str(ipaddress.ip_address(str(raw.get("ip", "")).strip()))
        except ValueError:
            continue
        if address not in allowed or address in seen:
            continue
        latency = _number(raw.get("latency_ms"), -1)
        speed = _number(raw.get("speed_mbps"), -1)
        loss = _number(raw.get("loss_pct"), 0)
        if not 0 < latency <= 60000 or not 0 < speed <= 100000 or not 0 <= loss <= 100:
            continue
        seen.add(address)
        candidate = allowed[address]
        accepted.append({
            "ip": address,
            "ip_type": candidate["ip_type"],
            "source": candidate["source"],
            "port": int(raw.get("port") or candidate.get("port") or 443),
            "latency_ms": round(latency, 1),
            "speed_mbps": round(speed, 2),
            "loss_pct": round(loss, 1),
            "colo": str(raw.get("colo", ""))[:16],
            "country": str(raw.get("country", ""))[:24],
            "path": path_name,
        })
    accepted.sort(key=lambda item: (-item["speed_mbps"], item["latency_ms"], item["ip"]))
    return accepted


def _tls_request(address, port, path, timeout, read_limit=0):
    started = time.monotonic()
    raw = tls = response = None
    try:
        raw = socket.create_connection((address, port), timeout=timeout)
        context = ssl.create_default_context()
        tls = context.wrap_socket(raw, server_hostname="speed.cloudflare.com")
        tls.settimeout(timeout)
        request = (
            f"GET {path} HTTP/1.1\r\nHost: speed.cloudflare.com\r\n"
            "User-Agent: Lun-CDN-Optimizer/2\r\nAccept: */*\r\nConnection: close\r\n\r\n"
        ).encode("ascii")
        tls.sendall(request)
        response = http.client.HTTPResponse(tls)
        response.begin()
        header_elapsed = time.monotonic() - started
        if response.status != 200:
            raise OSError(f"HTTP {response.status}")
        body = response.read(read_limit) if read_limit else b""
        headers = {key.lower(): value for key, value in response.getheaders()}
        return header_elapsed, body, headers
    finally:
        if response is not None:
            response.close()
        if tls is not None:
            tls.close()
        elif raw is not None:
            raw.close()


def _vps_probe_latency(candidate, port, timeout, attempts, cancel_event):
    values = []
    headers = {}
    for _ in range(attempts):
        if cancel_event.is_set():
            raise InterruptedError("cancelled")
        elapsed, _, headers = _tls_request(candidate["ip"], port, "/__down?bytes=0", timeout)
        values.append(elapsed * 1000)
    ray = headers.get("cf-ray", "")
    colo = ray.rsplit("-", 1)[-1] if "-" in ray else ""
    return round(statistics.median(values), 1), colo[:16]


def _vps_probe_speed(candidate, port, timeout, download_bytes, cancel_event):
    if cancel_event.is_set():
        raise InterruptedError("cancelled")
    started = time.monotonic()
    _, body, headers = _tls_request(
        candidate["ip"], port, f"/__down?bytes={download_bytes}", timeout, download_bytes
    )
    elapsed = max(0.001, time.monotonic() - started)
    ray = headers.get("cf-ray", "")
    colo = ray.rsplit("-", 1)[-1] if "-" in ray else ""
    return round(len(body) * 8 / elapsed / 1_000_000, 2), colo[:16]


class VpsTestJob:
    def __init__(self, candidates, settings):
        self.id = secrets.token_urlsafe(12)
        self.candidates = list(candidates)
        self.settings = settings
        self.cancel_event = threading.Event()
        self.lock = threading.Lock()
        self.state = "queued"
        self.stage = "等待"
        self.done = 0
        self.total = len(candidates)
        self.results = []
        self.rows = {}
        self.error = ""

    def snapshot(self):
        with self.lock:
            return {
                "job_id": self.id, "state": self.state, "stage": self.stage,
                "done": self.done, "total": self.total, "error": self.error,
                "results": list(self.results), "rows": list(self.rows.values()),
            }

    def run(self):
        settings = self.settings
        port_mode = settings["port"]
        concurrency = settings["concurrency"]
        timeout = settings["timeout_ms"] / 1000
        latency_max = settings["latency_max"]
        speed_limit = settings["speed_limit"]
        download_bytes = settings["download_bytes"]
        try:
            with self.lock:
                self.state, self.stage = "running", "VPS 延迟"

            def latency_worker(candidate):
                port = candidate.get("port") or port_mode
                if port == 0:
                    port = random.choice(CF_HTTPS_PORTS)
                try:
                    latency, colo = _vps_probe_latency(candidate, port, timeout, 3, self.cancel_event)
                    row = {**candidate, "port": port, "latency_ms": latency, "speed_mbps": 0,
                           "loss_pct": 0, "colo": colo, "country": "", "status": "延迟完成"}
                except InterruptedError:
                    return None
                except Exception as error:  # network failures are expected data
                    row = {**candidate, "port": port, "latency_ms": 0, "speed_mbps": 0,
                           "loss_pct": 100, "colo": "", "country": "", "status": "失败",
                           "error": str(error)[:80]}
                with self.lock:
                    self.rows[candidate["ip"]] = row
                    self.done += 1
                return row

            with concurrent.futures.ThreadPoolExecutor(max_workers=concurrency) as pool:
                list(pool.map(latency_worker, self.candidates))
            if self.cancel_event.is_set():
                raise InterruptedError
            with self.lock:
                eligible = [row for row in self.rows.values() if 0 < row["latency_ms"] <= latency_max]
                eligible.sort(key=lambda row: (row["latency_ms"], row["ip"]))
                finalists = eligible[:speed_limit]
                self.stage, self.done, self.total = "VPS 带宽", 0, len(finalists)

            def speed_worker(row):
                try:
                    speed, colo = _vps_probe_speed(
                        row, row["port"], settings["speed_timeout"], download_bytes, self.cancel_event
                    )
                    updated = {**row, "speed_mbps": speed, "colo": colo or row.get("colo", ""),
                               "status": "完成", "path": "vps"}
                except InterruptedError:
                    return None
                except Exception as error:
                    updated = {**row, "status": "失败", "error": str(error)[:80]}
                with self.lock:
                    self.rows[row["ip"]] = updated
                    self.done += 1
                return updated

            with concurrent.futures.ThreadPoolExecutor(max_workers=concurrency) as pool:
                list(pool.map(speed_worker, finalists))
            if self.cancel_event.is_set():
                raise InterruptedError
            with self.lock:
                self.results = _validate_measurements(list(self.rows.values()), self.candidates, "vps")
                self.state, self.stage = "complete", "完成"
        except InterruptedError:
            with self.lock:
                self.state, self.stage = "cancelled", "已停止"
        except Exception as error:
            with self.lock:
                self.state, self.stage, self.error = "failed", "失败", str(error)[:200]


def _preview_digest(secret, selected):
    payload = json.dumps(sorted(selected), ensure_ascii=False, separators=(",", ":")).encode("utf-8")
    return hmac.new(secret, payload, hashlib.sha256).hexdigest()


PAGE = r'''<!doctype html>
<html lang="zh-CN"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<title>Lun 一键优选 IP 2.0</title>
<style>
:root{color-scheme:dark;--bg:#080a0d;--surface:#101419;--surface2:#151a20;--line:#2a3139;--text:#edf2f4;--muted:#95a0a8;--cyan:#18c7c2;--orange:#ff9a28;--green:#35cf78;--red:#ff646e;--yellow:#f5c84c}
*{box-sizing:border-box}html,body{max-width:100%;overflow-x:hidden}body{margin:0;background:var(--bg);color:var(--text);font:14px/1.45 "Microsoft YaHei UI","Noto Sans CJK SC",sans-serif}.wrap{max-width:1500px;margin:auto;padding:18px}.top{display:flex;justify-content:space-between;gap:18px;align-items:flex-end;padding:10px 0 18px;border-bottom:1px solid var(--line)}.top>div{min-width:0}h1{font-size:24px;margin:0;letter-spacing:.02em}.brand{color:var(--cyan)}.version{color:var(--muted);font:12px ui-monospace,monospace}.sub{color:var(--muted);margin-top:5px;overflow-wrap:anywhere}.grid4{display:grid;grid-template-columns:repeat(4,1fr);gap:1px;background:var(--line);border:1px solid var(--line);margin:14px 0}.metric{background:var(--surface);padding:12px 14px;min-width:0}.metric label{display:block;color:var(--muted);font-size:12px}.metric strong{display:block;margin-top:5px;white-space:nowrap;overflow:hidden;text-overflow:ellipsis}.panel{border:1px solid var(--line);background:var(--surface);margin-top:12px;min-width:0;max-width:100%}.panel-head{display:flex;justify-content:space-between;gap:12px;align-items:center;padding:11px 13px;border-bottom:1px solid var(--line);background:var(--surface2)}.panel-head h2{font-size:15px;margin:0}.panel-body{padding:12px}.formgrid{display:grid;grid-template-columns:2fr 1fr 1fr 1fr;gap:10px}.field label{display:block;color:var(--muted);font-size:12px;margin-bottom:5px}select,input,textarea{width:100%;border:1px solid #343d47;background:#090c10;color:var(--text);padding:8px;border-radius:3px;font:inherit}textarea{min-height:100px;resize:vertical;font-family:ui-monospace,monospace}.row{display:flex;gap:8px;align-items:center;flex-wrap:wrap}.row>*{width:auto}button{border:1px solid #3b4651;background:#202831;color:var(--text);padding:8px 13px;border-radius:3px;font-weight:700;cursor:pointer}button.primary{background:#087f7c;border-color:#14bcb7}button.orange{background:#9a5410;border-color:#d8781b}button.danger{background:#5d2228;border-color:#9d3640}button:disabled{opacity:.45;cursor:not-allowed}.notice{padding:9px 11px;border:1px solid #6f5d1e;background:#211d0c;color:#ffe49a;margin-top:10px;overflow-wrap:anywhere}.ok{color:var(--green)}.bad{color:var(--red)}.warn{color:var(--yellow)}.muted{color:var(--muted)}.progress{height:7px;background:#050608;margin-top:8px;overflow:hidden}.bar{height:100%;background:linear-gradient(90deg,var(--cyan),var(--orange));width:0;transition:width .2s}.dual{display:grid;grid-template-columns:minmax(0,1fr) minmax(0,1fr);gap:12px;min-width:0}.tools{display:flex;gap:7px;flex-wrap:wrap;min-width:0}.tools input,.tools select{width:auto;min-width:100px;max-width:100%;padding:6px}.tablebox{overflow:auto;max-height:520px;min-width:0;max-width:100%}table{width:100%;border-collapse:collapse;font-variant-numeric:tabular-nums;white-space:nowrap}th,td{padding:8px;border-bottom:1px solid #242b32;text-align:left}th{position:sticky;top:0;background:#171d23;color:#aeb8bf;font-size:12px;z-index:1}tbody tr:hover{background:#151b20}td.ip{font-family:ui-monospace,monospace}.status{font-size:12px}.pill{display:inline-block;padding:1px 6px;border:1px solid #37624b;color:var(--green)}.selected-row{background:#10231b}.empty{text-align:center;color:var(--muted);padding:24px}.preview{display:none}.preview.show{display:block}.diff{display:grid;grid-template-columns:repeat(3,1fr);gap:8px}.diff>div{background:#0b0f13;border:1px solid var(--line);padding:10px;min-height:72px}.diff-item{display:flex;align-items:center;justify-content:space-between;gap:8px;margin-top:5px}.diff-item code{color:var(--muted);word-break:break-all}.diff-item button{padding:2px 8px;font-size:12px;white-space:nowrap}.foot{color:var(--muted);font-size:12px;padding:18px 0}.foot a{color:var(--cyan)}details{margin-top:10px}summary{cursor:pointer;color:var(--cyan)}.check{accent-color:var(--green)}
@media(max-width:1000px){.dual{grid-template-columns:1fr}.formgrid{grid-template-columns:1fr 1fr}.grid4{grid-template-columns:1fr 1fr}}
@media(max-width:600px){.wrap{padding:9px}.top{align-items:flex-start;flex-direction:column}.top>div{width:100%}.sub{max-width:100%;white-space:normal}.formgrid{grid-template-columns:1fr}.grid4{grid-template-columns:1fr}.diff{grid-template-columns:1fr}.panel-body{padding:8px}th,td{padding:7px 6px}}
</style></head><body><main class="wrap">
<header class="top"><div><h1><span class="brand">Lun</span> 一键优选 IP 2.0</h1><div class="sub">客户端线路与 VPS 出口分别测试、分别排行；应用前先检查替换差异。</div></div><div class="version" id="version">正在建立会话…</div></header>
<section class="grid4"><div class="metric"><label>客户端连接 IP</label><strong id="clientNet">读取中</strong></div><div class="metric"><label>实际测速 IP / 地区</label><strong id="clientIp">等待客户端测试</strong></div><div class="metric"><label>VPS 测试出口</label><strong id="vpsIdentity">当前 Lun 服务器</strong></div><div class="metric"><label>候选库状态</label><strong id="sourceState">载入中</strong></div></section>
<div id="networkNotice" class="notice" style="display:none"></div>
<section class="panel"><div class="panel-head"><h2>候选 IP 与测试参数</h2><span class="muted" id="candidateSummary">-</span></div><div class="panel-body">
<div class="formgrid"><div class="field"><label>IP 库</label><select id="source"></select></div><div class="field"><label>候选数量（1–4096）</label><input id="limit" type="number" min="1" max="4096" value="512"></div><div class="field"><label>测试端口</label><select id="port"><option value="-1">自动 / 当前 Lun 端口</option><option value="0">随机 HTTPS 端口</option><option>443</option><option>2053</option><option>2083</option><option>2087</option><option>2096</option><option>8443</option></select></div><div class="field"><label>默认选择数量</label><input id="top" type="number" min="1" max="50" value="5"></div></div>
<div class="row" style="margin-top:9px"><button id="refresh">刷新 IP 库</button><button id="manualToggle">手工导入</button><span class="muted" id="sourceMeta"></span></div>
<div id="manualBox" style="display:none;margin-top:9px"><textarea id="manual" placeholder="支持 Lun 的空格/逗号/换行分隔 IP，也支持 IP:端口#备注、[IPv6]:端口#备注、CIDR 和 IP起点-IP终点；不接受远程 URL。"></textarea><button id="manualLoad" style="margin-top:6px">载入手工候选</button></div>
<details><summary>高级测试参数与流量估算</summary><div class="formgrid" style="margin-top:9px"><div class="field"><label>最大延迟 ms</label><input id="latencyMax" type="number" min="1" max="3000" value="150"></div><div class="field"><label>最低带宽 Mbps</label><input id="speedMin" type="number" min="0.1" max="10000" value="80"></div><div class="field"><label>客户端并发 1–32</label><input id="clientConcurrency" type="number" min="1" max="32" value="16"></div><div class="field"><label>VPS 并发 1–16</label><input id="vpsConcurrency" type="number" min="1" max="16" value="8"></div><div class="field"><label>单次超时 ms</label><input id="timeoutMs" type="number" min="100" max="10000" value="800"></div><div class="field"><label>带宽复测候选 1–100</label><input id="speedLimit" type="number" min="1" max="100" value="20"></div><div class="field"><label>单项下载 MB</label><input id="downloadMb" type="number" min="0.1" max="20" step="0.1" value="5"></div><div class="field"><label>带宽超时秒</label><input id="speedTimeout" type="number" min="2" max="30" value="8"></div></div><div class="notice" id="traffic">默认最多约消耗：客户端 100 MB + VPS 100 MB。</div></details>
</div></section>
<section class="panel"><div class="panel-head"><h2>双向测试控制台</h2><div class="row"><button class="primary" id="start">一键双向优选</button><button id="stop" disabled>停止测试</button><button class="danger" id="cancel">取消并关闭</button></div></div><div class="panel-body"><div id="globalStatus">等待开始。</div><div class="dual"><div><div class="muted" id="clientStatus">客户端：等待</div><div class="progress"><div class="bar" id="clientBar"></div></div></div><div><div class="muted" id="vpsStatus">VPS：等待</div><div class="progress"><div class="bar" id="vpsBar"></div></div></div></div></div></section>
<div class="dual">
<section class="panel"><div class="panel-head"><h2>客户端榜</h2><span class="muted">用户当前网络 → Cloudflare</span></div><div class="panel-body"><div class="tools"><input id="clientSearch" placeholder="筛选 IP / 来源 / COLO"><select id="clientFamily"><option value="">全部地址</option><option>IPv4</option><option>IPv6</option></select><select id="clientSort"><option value="speed">带宽优先</option><option value="latency">延迟优先</option></select><button data-action="all" data-list="client">全选</button><button data-action="invert" data-list="client">反选</button><button data-action="csv" data-list="client">CSV</button></div></div><div class="tablebox"><table><thead><tr><th>选</th><th>IP</th><th>类型</th><th>来源</th><th>端口</th><th>COLO</th><th>延迟</th><th>失败率</th><th>带宽</th><th>状态</th><th>操作</th></tr></thead><tbody id="clientRows"><tr><td colspan="11" class="empty">尚未测试</td></tr></tbody></table></div></section>
<section class="panel"><div class="panel-head"><h2>VPS 榜</h2><span class="muted">Lun 服务器 → Cloudflare</span></div><div class="panel-body"><div class="tools"><input id="vpsSearch" placeholder="筛选 IP / 来源 / COLO"><select id="vpsFamily"><option value="">全部地址</option><option>IPv4</option><option>IPv6</option></select><select id="vpsSort"><option value="speed">带宽优先</option><option value="latency">延迟优先</option></select><button data-action="all" data-list="vps">全选</button><button data-action="invert" data-list="vps">反选</button><button data-action="csv" data-list="vps">CSV</button></div></div><div class="tablebox"><table><thead><tr><th>选</th><th>IP</th><th>类型</th><th>来源</th><th>端口</th><th>COLO</th><th>延迟</th><th>失败率</th><th>带宽</th><th>状态</th><th>操作</th></tr></thead><tbody id="vpsRows"><tr><td colspan="11" class="empty">尚未测试</td></tr></tbody></table></div></section>
</div>
<section class="panel"><div class="panel-head"><h2>应用到 Lun</h2><div class="row"><button id="copy">复制最终 IP</button><button id="reset">清空选择</button><button class="orange" id="preview">预览替换</button></div></div><div class="panel-body"><div>最终列表共 <strong class="ok" id="selectedCount">0</strong> 个地址；“删除”中的旧 IP 可点击右侧“保留”移回保留区。</div><div id="previewBox" class="preview"><div class="diff" style="margin-top:10px"><div><strong class="ok">新增</strong><div id="diffAdd"></div></div><div><strong>保留</strong><div id="diffKeep"></div></div><div><strong class="bad">删除</strong><div id="diffRemove"></div></div></div><div class="notice">确认后将替换现有优选池并返回 SSH 重建订阅。</div><button class="primary" id="apply">确认替换并应用</button></div></div></section>
<footer class="foot">候选数据默认来自 <a href="https://github.com/DustinWin/BestCF" target="_blank" rel="noopener">DustinWin/BestCF</a>，VPS 测速使用 <a href="https://github.com/cloudflare/speedtest" target="_blank" rel="noopener">Cloudflare Speedtest</a> 端点；客户端探测兼容 BestCF/HiDNS 方案。测试结果只代表当时线路质量。</footer>
</main><script>
const $=s=>document.querySelector(s),$$=s=>[...document.querySelectorAll(s)];
const state={cfg:null,candidates:[],client:[],vps:[],vpsRows:[],selected:new Set(),retained:new Set(),cancelled:false,controllers:new Set(),preview:null,helper:null,clientIp:null,clientMeta:null,defaulted:false};
const helpers=['bestcf.cmliussss.hidns.vip','ns.psb.kdns.fr'];
const esc=v=>String(v??'').replace(/[&<>"']/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]));
const route=s=>location.pathname.replace(/\/$/,'')+'/'+s;
const num=(id,min,max)=>{const n=Number($(id).value);if(!Number.isFinite(n)||n<min||n>max)throw Error(`${id} 参数超出范围`);return n};
async function api(path,opt={}){const r=await fetch(route(path),{cache:'no-store',...opt});let d={};try{d=await r.json()}catch(e){}if(!r.ok)throw Error(d.error||`HTTP ${r.status}`);return d}
function post(path,data={}){return api(path,{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify(data)})}
function abortable(url,ms,opt={}){const c=new AbortController(),timer=setTimeout(()=>c.abort(),ms);state.controllers.add(c);return fetch(url,{...opt,cache:'no-store',signal:c.signal}).finally(()=>{clearTimeout(timer);state.controllers.delete(c)})}
async function pool(items,concurrency,fn,onProgress){let next=0,done=0;async function worker(){while(!state.cancelled){const i=next++;if(i>=items.length)return;await fn(items[i],i).catch(()=>{});done++;onProgress?.(done,items.length)}}await Promise.all(Array.from({length:Math.min(concurrency,items.length)},worker))}
function settings(){return{limit:num('#limit',1,4096),top:num('#top',1,50),port:num('#port',-1,65535),latencyMax:num('#latencyMax',1,3000),speedMin:num('#speedMin',.1,10000),clientConcurrency:num('#clientConcurrency',1,32),vpsConcurrency:num('#vpsConcurrency',1,16),timeoutMs:num('#timeoutMs',100,10000),speedLimit:num('#speedLimit',1,100),downloadBytes:Math.round(num('#downloadMb',.1,20)*1e6),speedTimeout:num('#speedTimeout',2,30)}}
function updateTraffic(){try{const s=settings(),mb=(s.speedLimit*s.downloadBytes/1e6).toFixed(0);$('#traffic').textContent=`预计上限：客户端约 ${mb} MB + VPS约 ${mb} MB；实际仅对低延迟候选测速。`}catch(e){}}
function sourceText(meta){const t=meta.fetched_at?new Date(meta.fetched_at*1000).toLocaleString():'未知';return `${meta.name||'-'} · ${meta.cached?'缓存':'实时'} · ${t}`}
function updateCandidates(data){state.candidates=data.candidates||[];state.client=[];state.vps=[];state.vpsRows=[];state.selected.clear();state.retained.clear();state.clientIp=null;state.clientMeta=null;state.defaulted=false;state.preview=null;$('#clientIp').textContent='等待客户端测试';$('#networkNotice').textContent=`页面连接 IP：${state.cfg.client_ip||'未知'}。开始后会显示实际测速出口；只有该 IP 完成的结果才会进入客户端榜。`;$('#previewBox').classList.remove('show');$('#candidateSummary').textContent=`${state.candidates.length} 个候选` ;$('#sourceState').textContent=data.source.cached?'使用最近缓存':'实时数据';$('#sourceState').className=data.source.cached?'warn':'ok';$('#sourceMeta').textContent=sourceText(data.source);renderAll()}
async function refresh(manual=''){try{setGlobal('正在刷新候选库…');const d=await post('import',manual?{manual,limit:settings().limit}:{source_key:$('#source').value,limit:settings().limit});updateCandidates(d);setGlobal(`已载入 ${d.candidates.length} 个候选。`,'ok')}catch(e){setGlobal(e.message,'bad')}}
function setGlobal(text,cls=''){const el=$('#globalStatus');el.textContent=text;el.className=cls}
function encodeIp(ip){return ip.includes(':')?ip.toLowerCase().replaceAll(':','-'):ip.split('.').map(x=>(+x).toString(16).padStart(2,'0')).join('').toUpperCase()}
function candidatePort(c){const selected=settings().port;return c.port||(selected===-1?state.cfg.test_port:selected)||443}
function probeUrl(c,helper,path,extra={}){const q=new URLSearchParams({_t:Date.now(),...extra});return `https://${encodeIp(c.ip)}.${helper}:${candidatePort(c)}/${path}?${q}`}
function metaIp(meta){return String(meta?.ip||meta?.clientIp||meta?.client_ip||'').trim()}
function showClientIdentity(meta){const ip=metaIp(meta);if(!ip)throw Error('探测未返回客户端 IP');if(state.clientIp&&state.clientIp!==ip)throw Error(`客户端测速出口已从 ${state.clientIp} 变为 ${ip}`);state.clientIp=ip;state.clientMeta=meta;const place=[meta.country,meta.region,meta.city,meta.colo].filter(Boolean).join(' / ')||'地区未知';$('#clientIp').textContent=`${ip} / ${place}`;const pageIp=state.cfg.client_ip,org=meta.asOrganization||meta.org||'';$('#networkNotice').style.display='block';if(pageIp&&pageIp!==ip){$('#networkNotice').textContent=`页面连接 IP 是 ${pageIp}，实际测速 IP 是 ${ip}（可能使用了代理或分流）。客户端榜只计入由 ${ip} 完成的结果。`}else{$('#networkNotice').textContent=`客户端测速 IP 已确认为 ${ip}${org?` · ${org}`:''}；客户端榜只计入该出口的结果。`}return ip}
async function chooseHelper(){const c=state.candidates[0];if(!c)throw Error('没有候选 IP');for(const helper of helpers){try{const r=await abortable(probeUrl(c,helper,'ip.json'),3000);if(r.ok){const meta=await r.json();showClientIdentity(meta);state.helper=helper;localStorage.setItem('lun-cdnopt-helper',helper);return helper}}catch(e){}}throw Error('客户端测速线路连接失败；客户端榜未生成结果，VPS 榜仍可单独使用')}
async function clientLatency(c,s){let ok=0,failed=0,values=[],meta={};for(let i=0;i<3;i++){if(state.cancelled)throw Error('cancelled');const started=performance.now();try{const r=await abortable(probeUrl(c,state.helper,'ip.json'),Math.max(2500,s.timeoutMs*4));if(!r.ok)throw Error('HTTP');meta=await r.json();showClientIdentity(meta);values.push(performance.now()-started);ok++}catch(e){failed++}}if(!ok)throw Error('全部失败');values.sort((a,b)=>a-b);return{...c,port:candidatePort(c),latency_ms:values[Math.floor(values.length/2)],loss_pct:failed/3*100,speed_mbps:0,colo:meta.colo||'',country:meta.country||'',status:'延迟完成'}}
async function clientSpeed(row,s){const started=performance.now();let bytes=0;const r=await abortable(probeUrl(row,state.helper,'__down',{bytes:s.downloadBytes}),s.speedTimeout*1000);if(!r.ok)throw Error('HTTP');if(r.body?.getReader){const reader=r.body.getReader();while(true){const p=await reader.read();if(p.done)break;bytes+=p.value.byteLength}}else bytes=(await r.arrayBuffer()).byteLength;return{...row,speed_mbps:bytes*8/Math.max(.001,(performance.now()-started)/1000)/1e6,status:'完成'}}
async function runClient(s){$('#clientStatus').textContent='客户端：选择可用测速线路…';try{const cached=localStorage.getItem('lun-cdnopt-helper');if(cached&&helpers.includes(cached))helpers.splice(helpers.indexOf(cached),1),helpers.unshift(cached);await chooseHelper()}catch(e){$('#clientIp').textContent='测速线路连接失败';$('#clientStatus').innerHTML=`客户端：<span class="warn">${esc(e.message)}</span>`;return}const rows=new Map(state.candidates.map(c=>[c.ip,{...c,port:candidatePort(c),status:'等待'}]));state.client=[];const latency=[];await pool(state.candidates,s.clientConcurrency,async c=>{rows.set(c.ip,{...rows.get(c.ip),status:'延迟测试'});try{const r=await clientLatency(c,s);latency.push(r);rows.set(c.ip,r)}catch(e){rows.set(c.ip,{...rows.get(c.ip),status:'失败',loss_pct:100})}},(d,t)=>{$('#clientBar').style.width=`${d/t*70}%`;$('#clientStatus').textContent=`客户端：延迟 ${d}/${t}`;if(d%10===0||d===t){state.client=[...rows.values()];renderList('client')}});if(state.cancelled)return;const finalists=latency.filter(x=>x.latency_ms<=s.latencyMax).sort((a,b)=>a.latency_ms-b.latency_ms).slice(0,s.speedLimit);await pool(finalists,Math.min(6,s.clientConcurrency),async row=>{rows.set(row.ip,{...row,status:'带宽测试'});try{rows.set(row.ip,await clientSpeed(row,s))}catch(e){rows.set(row.ip,{...row,status:'失败'})}},(d,t)=>{$('#clientBar').style.width=`${70+d/t*30}%`;$('#clientStatus').textContent=`客户端：带宽 ${d}/${t}`;state.client=[...rows.values()];renderList('client')});state.client=[...rows.values()].filter(x=>x.speed_mbps>0).sort((a,b)=>b.speed_mbps-a.speed_mbps||a.latency_ms-b.latency_ms);await post('client-results',{client_ip:state.clientIp,measurements:state.client});if(!state.defaulted){state.client.filter(x=>x.latency_ms<=s.latencyMax&&x.speed_mbps>=s.speedMin).slice(0,s.top).forEach(x=>state.selected.add(x.ip));state.defaulted=true}$('#clientBar').style.width='100%';$('#clientStatus').textContent=`客户端：完成，${state.client.length} 个带宽结果（出口 ${state.clientIp}）`;renderAll()}
async function runVps(s){await post('vps-test/start',{port:s.port===-1?state.cfg.test_port:s.port,concurrency:s.vpsConcurrency,timeout_ms:s.timeoutMs,latency_max:s.latencyMax,speed_limit:s.speedLimit,download_bytes:s.downloadBytes,speed_timeout:s.speedTimeout});while(!state.cancelled){const d=await api('vps-test/status');state.vps=d.results||[];state.vpsRows=d.rows||[];const pct=d.total?d.done/d.total*100:0;$('#vpsBar').style.width=`${pct}%`;$('#vpsStatus').textContent=`VPS：${d.stage} ${d.done}/${d.total}`;renderList('vps');if(['complete','failed','cancelled'].includes(d.state)){if(d.state==='failed')$('#vpsStatus').innerHTML=`VPS：<span class="bad">${esc(d.error||'失败')}</span>`;else if(d.state==='complete'){$('#vpsBar').style.width='100%';$('#vpsStatus').textContent=`VPS：完成，${state.vps.length} 个带宽结果`}return}await new Promise(r=>setTimeout(r,450))}}
async function start(){let s;try{s=settings()}catch(e){setGlobal(e.message,'bad');return}state.cancelled=false;state.controllers.forEach(c=>c.abort());state.controllers.clear();state.client=[];state.vps=[];state.vpsRows=[];state.selected.clear();state.retained.clear();state.clientIp=null;state.clientMeta=null;state.preview=null;state.defaulted=false;$('#clientIp').textContent='正在确认实际测速出口…';$('#previewBox').classList.remove('show');$('#start').disabled=true;$('#stop').disabled=false;setGlobal('双向测试运行中；两个榜单独立计算，不做隐藏加权。');const results=await Promise.allSettled([runClient(s),runVps(s)]);if(!state.cancelled){const failures=results.filter(x=>x.status==='rejected');if(failures.length===2)setGlobal('客户端和 VPS 测试均失败，请检查网络与端口。','bad');else if(failures.length)setGlobal('一侧测试失败，另一侧结果仍可选择。','warn');else setGlobal('双向测试完成，可跨榜选择并预览替换。','ok')}$('#start').disabled=false;$('#stop').disabled=true;renderAll()}
async function stop(){state.cancelled=true;state.controllers.forEach(c=>c.abort());state.controllers.clear();try{await post('vps-test/cancel',{})}catch(e){}$('#stop').disabled=true;$('#start').disabled=false;setGlobal('测试已停止；已有成功结果仍可使用。','warn')}
function visibleRows(kind){const source=kind==='client'?state.client:(state.vps.length?state.vps:state.vpsRows);const search=$(`#${kind}Search`).value.toLowerCase(),family=$(`#${kind}Family`).value,sort=$(`#${kind}Sort`).value;return source.filter(x=>(!family||x.ip_type===family)&&(!search||`${x.ip} ${x.source} ${x.colo} ${x.country}`.toLowerCase().includes(search))).sort((a,b)=>sort==='latency'?(a.latency_ms||1e9)-(b.latency_ms||1e9):((b.speed_mbps||0)-(a.speed_mbps||0)||(a.latency_ms||1e9)-(b.latency_ms||1e9)))}
function renderList(kind){const rows=visibleRows(kind),body=$(`#${kind}Rows`);if(!rows.length){body.innerHTML='<tr><td colspan="11" class="empty">暂无结果</td></tr>';return}body.innerHTML=rows.map(x=>{const checked=state.selected.has(x.ip),success=x.speed_mbps>0;return `<tr class="${checked?'selected-row':''}"><td><input class="check result-check" data-ip="${esc(x.ip)}" type="checkbox" ${checked?'checked':''} ${success?'':'disabled'}></td><td class="ip">${esc(x.ip)}</td><td>${esc(x.ip_type)}</td><td title="${esc(x.source)}">${esc(x.source)}</td><td>${x.port||'-'}</td><td>${esc(x.colo||'-')}</td><td>${x.latency_ms?x.latency_ms.toFixed(0)+' ms':'-'}</td><td>${Number.isFinite(x.loss_pct)?x.loss_pct.toFixed(0)+'%':'-'}</td><td>${x.speed_mbps?x.speed_mbps.toFixed(1)+' Mbps':'-'}</td><td class="status">${success?'<span class="pill">成功</span>':esc(x.status||'-')}</td><td><button class="retry" data-kind="${kind}" data-ip="${esc(x.ip)}">重测</button></td></tr>`}).join('');body.querySelectorAll('.result-check').forEach(el=>el.onchange=()=>{el.checked?state.selected.add(el.dataset.ip):state.selected.delete(el.dataset.ip);state.preview=null;$('#previewBox').classList.remove('show');renderAll()});body.querySelectorAll('.retry').forEach(el=>el.onclick=()=>retryOne(el.dataset.kind,el.dataset.ip,el))}
async function retryOne(kind,ip,button){const s=settings(),candidate=state.candidates.find(x=>x.ip===ip);if(!candidate)return;button.disabled=true;button.textContent='测试中';try{let result;if(kind==='client'){if(!state.helper)await chooseHelper();const latency=await clientLatency(candidate,s);result=await clientSpeed(latency,s);state.client=[...state.client.filter(x=>x.ip!==ip),result].sort((a,b)=>b.speed_mbps-a.speed_mbps||a.latency_ms-b.latency_ms);await post('client-results',{client_ip:state.clientIp,measurements:state.client})}else{const d=await post('vps-test/retry',{ip,port:candidatePort(candidate),timeout_ms:s.timeoutMs,download_bytes:s.downloadBytes,speed_timeout:s.speedTimeout});result=d.result;state.vps=[...state.vps.filter(x=>x.ip!==ip),result].sort((a,b)=>b.speed_mbps-a.speed_mbps||a.latency_ms-b.latency_ms)}setGlobal(`${kind==='client'?'客户端':'VPS'}单项重测完成：${ip}`,'ok');state.preview=null;$('#previewBox').classList.remove('show')}catch(e){setGlobal(`单项重测失败：${e.message}`,'bad')}renderAll()}
function finalIps(){return new Set([...state.selected,...state.retained])}
function renderAll(){renderList('client');renderList('vps');$('#selectedCount').textContent=finalIps().size}
function listAction(kind,action){const rows=visibleRows(kind).filter(x=>x.speed_mbps>0);if(action==='all')rows.forEach(x=>state.selected.add(x.ip));if(action==='invert')rows.forEach(x=>state.selected.has(x.ip)?state.selected.delete(x.ip):state.selected.add(x.ip));if(action==='csv'){const head='IP,类型,来源,端口,COLO,延迟ms,失败率%,带宽Mbps\n';const body=rows.map(x=>[x.ip,x.ip_type,`"${String(x.source).replaceAll('"','""')}"`,x.port,x.colo,x.latency_ms,x.loss_pct,x.speed_mbps].join(',')).join('\n');download(`${kind}-results.csv`,head+body)}state.preview=null;$('#previewBox').classList.remove('show');renderAll()}
function download(name,text){const a=document.createElement('a');a.href=URL.createObjectURL(new Blob([text],{type:'text/csv;charset=utf-8'}));a.download=name;a.click();setTimeout(()=>URL.revokeObjectURL(a.href),1000)}
async function refreshPreview(){if(!finalIps().size){state.preview=null;$('#previewBox').classList.remove('show');renderAll();return}await preview()}
function showDiff(id,items,kind=''){const root=$(id);root.innerHTML=items.length?items.map(x=>{let action='';if(kind==='remove')action=`<button class="keep-ip" data-ip="${esc(x)}">保留</button>`;else if(kind==='keep')action=`<button class="remove-ip" data-ip="${esc(x)}">删除</button>`;return `<div class="diff-item"><code>${esc(x)}</code>${action}</div>`}).join(''):'<span class="muted">无</span>';root.querySelectorAll('.keep-ip').forEach(b=>b.onclick=async()=>{state.retained.add(b.dataset.ip);await refreshPreview()});root.querySelectorAll('.remove-ip').forEach(b=>b.onclick=async()=>{state.selected.delete(b.dataset.ip);state.retained.delete(b.dataset.ip);await refreshPreview()})}
async function preview(){try{const d=await post('preview',{selected:[...state.selected],retained:[...state.retained]});state.preview=d;showDiff('#diffAdd',d.added);showDiff('#diffKeep',d.kept,'keep');showDiff('#diffRemove',d.removed,'remove');$('#previewBox').classList.add('show');renderAll()}catch(e){setGlobal(e.message,'bad')}}
async function apply(){if(!state.preview)return;$('#apply').disabled=true;try{const d=await post('apply',{selected:[...state.selected],retained:[...state.retained],digest:state.preview.digest});setGlobal(`已应用 ${d.selected.length} 个 IP，请返回 SSH 查看订阅重建。`,'ok')}catch(e){setGlobal(e.message,'bad');$('#apply').disabled=false}}
async function init(){try{const d=await api('config');state.cfg=d;state.candidates=d.candidates;$('#version').textContent=`模块 ${d.version} · 15分钟临时会话`;$('#clientNet').textContent=d.client_ip||'未知';$('#vpsIdentity').textContent=`${d.vps.ip} / ${d.vps.region}`;$('#source').innerHTML=d.sources.map(x=>`<option value="${esc(x.key)}" ${x.key===d.source.key?'selected':''}>${esc(x.name)}</option>`).join('');$('#limit').value=d.defaults.candidate_limit;$('#top').value=d.top_count;$('#latencyMax').value=d.latency_max;$('#speedMin').value=d.speed_min;$('#port').querySelector('option[value="-1"]').textContent=`自动 / 当前 Lun 端口（${d.test_port}）`;$('#sourceMeta').textContent=sourceText(d.source);$('#sourceState').textContent=d.source.cached?'使用最近缓存':'实时数据';$('#sourceState').className=d.source.cached?'warn':'ok';$('#candidateSummary').textContent=`${d.candidates.length} 个候选`;$('#networkNotice').style.display='block';$('#networkNotice').textContent=`页面连接 IP：${d.client_ip||'未知'}。点击“一键双向优选”后会显示实际测速出口；只有该 IP 完成的结果才会进入客户端榜。`;renderAll();updateTraffic();setGlobal('候选库已就绪，可调整参数后开始双向测试。','ok')}catch(e){setGlobal(`会话载入失败：${e.message}`,'bad')}}
$('#refresh').onclick=()=>refresh();$('#manualToggle').onclick=()=>{$('#manualBox').style.display=$('#manualBox').style.display==='none'?'block':'none'};$('#manualLoad').onclick=()=>refresh($('#manual').value);$('#start').onclick=start;$('#stop').onclick=stop;$('#cancel').onclick=async()=>{await stop();try{await post('cancel',{})}catch(e){}setGlobal('已取消，可关闭页面。','warn')};$('#preview').onclick=preview;$('#apply').onclick=apply;$('#copy').onclick=()=>navigator.clipboard.writeText([...finalIps()].join('\n')).then(()=>setGlobal('已复制最终 IP。','ok')).catch(()=>setGlobal('浏览器拒绝剪贴板，请使用 CSV。','warn'));$('#reset').onclick=()=>{state.selected.clear();state.retained.clear();state.preview=null;$('#previewBox').classList.remove('show');renderAll()};
$$('[data-action]').forEach(b=>b.onclick=()=>listAction(b.dataset.list,b.dataset.action));['clientSearch','clientFamily','clientSort','vpsSearch','vpsFamily','vpsSort'].forEach(id=>$(`#${id}`).oninput=()=>renderList(id.startsWith('client')?'client':'vps'));['speedLimit','downloadMb'].forEach(id=>$(`#${id}`).oninput=updateTraffic);init();
</script></body></html>'''


class OptimizerServer(ThreadingHTTPServer):
    daemon_threads = True
    allow_reuse_address = True


class OptimizerHandler(BaseHTTPRequestHandler):
    server_version = "LunCDNOptimizer/2"

    def log_message(self, fmt, *args):
        if getattr(self.server, "verbose", False):
            super().log_message(fmt, *args)

    def _route(self):
        path = urlsplit(self.path).path.strip("/")
        parts = path.split("/") if path else []
        if not parts or parts[0] != self.server.session_token:
            return None
        return "/".join(parts[1:])

    def _headers(self, status, content_type, length):
        self.send_response(status)
        self.send_header("Content-Type", content_type)
        self.send_header("Content-Length", str(length))
        self.send_header("Cache-Control", "no-store")
        self.send_header("X-Content-Type-Options", "nosniff")
        self.send_header("Referrer-Policy", "no-referrer")
        self.send_header("X-Frame-Options", "DENY")
        self.send_header("Permissions-Policy", "geolocation=(), camera=(), microphone=()")
        self.send_header(
            "Content-Security-Policy",
            "default-src 'none'; style-src 'unsafe-inline'; script-src 'unsafe-inline'; "
            "connect-src 'self' https://*.bestcf.cmliussss.hidns.vip:* "
            "https://*.ns.psb.kdns.fr:*",
        )
        self.end_headers()

    def _send_bytes(self, status, payload, content_type):
        self._headers(status, content_type, len(payload))
        self.wfile.write(payload)

    def _send_json(self, status, data):
        self._send_bytes(status, json.dumps(data, ensure_ascii=False).encode("utf-8"), "application/json; charset=utf-8")

    def _read_json(self):
        try:
            length = int(self.headers.get("Content-Length", "0"))
        except ValueError as error:
            raise ValueError("请求长度无效") from error
        if length <= 0 or length > MAX_REQUEST_BYTES:
            raise ValueError("请求内容为空或超过 2 MiB")
        try:
            return json.loads(self.rfile.read(length).decode("utf-8"))
        except (UnicodeDecodeError, json.JSONDecodeError) as error:
            raise ValueError("JSON 格式无效") from error

    def _finish_later(self):
        threading.Thread(target=self.server.shutdown, daemon=True).start()

    def _public_config(self):
        with self.server.lock:
            return {
                "version": VERSION,
                "candidates": list(self.server.candidates),
                "source": dict(self.server.source_meta),
                "sources": [{"key": key, "name": value[0]} for key, value in SOURCES.items()],
                "current_ips": list(self.server.current_ips),
                "top_count": self.server.top_count,
                "latency_max": self.server.latency_max,
                "speed_min": self.server.speed_min,
                "test_port": self.server.test_port,
                "client_ip": str(self.client_address[0]),
                "vps": dict(self.server.vps_meta),
                "defaults": {"candidate_limit": self.server.candidate_limit, "client_concurrency": 16,
                             "vps_concurrency": 8, "speed_limit": 20, "download_bytes": 5_000_000,
                             "timeout_ms": 800, "speed_timeout": 8},
            }

    def do_GET(self):
        route = self._route()
        if route is None:
            self._send_json(404, {"error": "not found"})
            return
        if route in ("", "index.html"):
            self._send_bytes(200, PAGE.encode("utf-8"), "text/html; charset=utf-8")
            return
        if route == "config":
            self._send_json(200, self._public_config())
            return
        if route == "vps-test/status":
            job = self.server.vps_job
            self._send_json(200, job.snapshot() if job else {"state": "idle", "results": [], "rows": []})
            return
        self._send_json(404, {"error": "not found"})

    def do_POST(self):
        route = self._route()
        if route is None:
            self._send_json(404, {"error": "not found"})
            return
        if route == "cancel":
            if self.server.vps_job:
                self.server.vps_job.cancel_event.set()
            self.server.cancelled = True
            self._send_json(200, {"ok": True})
            self._finish_later()
            return
        try:
            request = self._read_json()
            if not isinstance(request, dict):
                raise ValueError("请求内容必须是 JSON 对象")
            if route == "import":
                self._import(request)
            elif route == "client-results":
                self._client_results(request)
            elif route == "vps-test/start":
                self._vps_start(request)
            elif route == "vps-test/cancel":
                self._vps_cancel()
            elif route == "vps-test/retry":
                self._vps_retry(request)
            elif route == "preview":
                self._preview(request)
            elif route == "apply":
                self._apply(request)
            else:
                self._send_json(404, {"error": "not found"})
        except (OSError, ValueError, urllib.error.URLError) as error:
            self._send_json(400, {"error": str(error)})

    def _import(self, request):
        if self.server.vps_job and self.server.vps_job.snapshot()["state"] in ("queued", "running"):
            raise ValueError("VPS 测试运行中，请先停止")
        limit = _bounded(request.get("limit"), 512, 1, MAX_CANDIDATES, "候选数量", True)
        manual = str(request.get("manual", ""))
        if manual:
            if len(manual.encode("utf-8")) > MAX_SOURCE_BYTES:
                raise ValueError("手工候选内容超过 1 MiB")
            candidates = _parse_candidate_lines(manual, limit, self.server.seed, "手动输入")
            meta = {"key": "manual", "name": "手动输入", "url": "", "cached": False, "fetched_at": int(time.time())}
        else:
            source_key = str(request.get("source_key", DEFAULT_SOURCE_KEY))
            candidates, meta = load_candidates(source_key, limit, self.server.cache_dir, seed=self.server.seed)
        with self.server.lock:
            self.server.candidates, self.server.source_meta = candidates, meta
            self.server.client_results, self.server.vps_retry_results, self.server.preview = [], [], None
            self.server.vps_job = None
        self._send_json(200, {"candidates": candidates, "source": meta})

    def _client_results(self, request):
        try:
            client_ip = str(_global_ip(str(request.get("client_ip", "")).strip()))
        except ValueError as error:
            raise ValueError("客户端测速结果缺少有效的实际出口 IP") from error
        results = _validate_measurements(request.get("measurements", []), self.server.candidates, "client")
        with self.server.lock:
            self.server.client_results = results
            self.server.client_test_ip = client_ip
            self.server.preview = None
        self._send_json(200, {"ok": True, "client_ip": client_ip, "results": results})

    def _vps_start(self, request):
        if self.server.vps_job and self.server.vps_job.snapshot()["state"] in ("queued", "running"):
            raise ValueError("VPS 测试已经运行")
        port = _bounded(request.get("port"), self.server.test_port, 0, 65535, "测试端口", True)
        if port not in (0, *CF_HTTPS_PORTS):
            raise ValueError("VPS 测试端口必须是 Cloudflare HTTPS 端口或 0（随机）")
        settings = {
            "port": port,
            "concurrency": _bounded(request.get("concurrency"), 8, 1, 16, "VPS 并发", True),
            "timeout_ms": _bounded(request.get("timeout_ms"), 800, 100, 10000, "超时", True),
            "latency_max": _bounded(request.get("latency_max"), 150, 1, 3000, "最大延迟"),
            "speed_limit": _bounded(request.get("speed_limit"), 20, 1, 100, "带宽复测数量", True),
            "download_bytes": _bounded(request.get("download_bytes"), 5_000_000, 100_000, 20_000_000, "下载字节", True),
            "speed_timeout": _bounded(request.get("speed_timeout"), 8, 2, 30, "带宽超时", True),
        }
        job = VpsTestJob(self.server.candidates, settings)
        self.server.vps_job = job
        threading.Thread(target=job.run, daemon=True).start()
        self._send_json(202, {"ok": True, "job_id": job.id})

    def _vps_cancel(self):
        if self.server.vps_job:
            self.server.vps_job.cancel_event.set()
        self._send_json(200, {"ok": True})

    def _vps_retry(self, request):
        raw_ip = str(request.get("ip", "")).strip()
        try:
            address = str(ipaddress.ip_address(raw_ip))
        except ValueError as error:
            raise ValueError("重测 IP 无效") from error
        candidate = next((item for item in self.server.candidates if item["ip"] == address), None)
        if candidate is None:
            raise ValueError("重测 IP 不属于本次候选")
        port = _bounded(request.get("port"), self.server.test_port, 0, 65535, "测试端口", True)
        if port == 0:
            port = random.choice(CF_HTTPS_PORTS)
        if port not in CF_HTTPS_PORTS:
            raise ValueError("重测端口不是 Cloudflare HTTPS 端口")
        timeout = _bounded(request.get("timeout_ms"), 800, 100, 10000, "超时", True) / 1000
        download_bytes = _bounded(request.get("download_bytes"), 5_000_000, 100_000, 20_000_000, "下载字节", True)
        speed_timeout = _bounded(request.get("speed_timeout"), 8, 2, 30, "带宽超时", True)
        cancel_event = threading.Event()
        latency, colo = _vps_probe_latency(candidate, port, timeout, 3, cancel_event)
        speed, speed_colo = _vps_probe_speed(candidate, port, speed_timeout, download_bytes, cancel_event)
        row = _validate_measurements([{**candidate, "port": port, "latency_ms": latency,
            "speed_mbps": speed, "loss_pct": 0, "colo": speed_colo or colo}], self.server.candidates, "vps")[0]
        with self.server.lock:
            self.server.vps_retry_results = [item for item in self.server.vps_retry_results if item["ip"] != address]
            self.server.vps_retry_results.append(row)
            self.server.preview = None
        self._send_json(200, {"ok": True, "result": row})

    def _validated_selection(self, raw_selected, raw_retained=None):
        if not isinstance(raw_selected, list):
            raise ValueError("选择结果必须是数组")
        if raw_retained is None:
            raw_retained = []
        if not isinstance(raw_retained, list):
            raise ValueError("保留结果必须是数组")
        selected = []
        retained = []
        allowed = {item["ip"] for item in self.server.candidates}
        successful = {item["ip"] for item in self.server.client_results}
        successful.update(item["ip"] for item in self.server.vps_retry_results)
        if self.server.vps_job:
            successful.update(item["ip"] for item in self.server.vps_job.snapshot()["results"])
        for raw in raw_selected:
            try:
                address = str(ipaddress.ip_address(str(raw).strip()))
            except ValueError as error:
                raise ValueError("选择中包含无效 IP") from error
            if address not in allowed or address not in successful:
                raise ValueError(f"{address} 不属于本次已成功测试的候选")
            if address not in selected:
                selected.append(address)
        current = set(self.server.current_ips)
        for raw in raw_retained:
            try:
                address = str(ipaddress.ip_address(str(raw).strip()))
            except ValueError as error:
                raise ValueError("保留结果中包含无效 IP") from error
            if address not in current:
                raise ValueError(f"{address} 不属于当前优选池，不能作为保留项")
            if address not in retained:
                retained.append(address)
        final = selected + [item for item in retained if item not in selected]
        if not final or len(final) > MAX_SELECTED:
            raise ValueError(f"请选择或保留 1-{MAX_SELECTED} 个 IP")
        return selected, retained, final

    def _preview(self, request):
        selected, retained, final = self._validated_selection(
            request.get("selected", []), request.get("retained", [])
        )
        current = list(self.server.current_ips)
        preview = {
            "selected": final,
            "tested": selected,
            "retained": retained,
            "added": [item for item in final if item not in current],
            "kept": [item for item in final if item in current],
            "removed": [item for item in current if item not in final],
        }
        preview["digest"] = _preview_digest(self.server.preview_secret, final)
        self.server.preview = preview
        self._send_json(200, preview)

    def _apply(self, request):
        _, _, selected = self._validated_selection(
            request.get("selected", []), request.get("retained", [])
        )
        expected = _preview_digest(self.server.preview_secret, selected)
        if not self.server.preview or not hmac.compare_digest(str(request.get("digest", "")), expected):
            raise ValueError("选择已变化，请重新查看替换预览")
        candidate_map = {item["ip"]: item for item in self.server.candidates}
        client_map = {item["ip"]: item for item in self.server.client_results}
        vps_results = self.server.vps_job.snapshot()["results"] if self.server.vps_job else []
        retry_map = {item["ip"]: item for item in self.server.vps_retry_results}
        vps_results = [item for item in vps_results if item["ip"] not in retry_map] + list(retry_map.values())
        vps_map = {item["ip"]: item for item in vps_results}
        rows = [{"ip": ip, "source": candidate_map.get(ip, {"source": "原优选池"})["source"],
                 "client": client_map.get(ip), "vps": vps_map.get(ip)} for ip in selected]
        result = {
            "version": VERSION, "created_at": int(time.time()), "source": self.server.source_meta,
            "selected": rows, "previous": self.server.current_ips,
            "client_test_ip": self.server.client_test_ip,
        }
        _atomic_json(self.server.result_file, result)
        self.server.applied = True
        self._send_json(200, {"ok": True, "selected": rows})
        self._finish_later()


def _display_host(host):
    value = host.strip()
    if value.startswith("[") and value.endswith("]"):
        return value
    try:
        parsed = ipaddress.ip_address(value)
    except ValueError:
        return value
    return f"[{parsed}]" if parsed.version == 6 else value


def serve(args):
    candidates, metadata = load_candidates(
        args.source_key, args.candidate_limit, args.cache_dir, args.source_file, args.seed
    )
    token = args.token or secrets.token_urlsafe(24)
    server = OptimizerServer((args.bind, args.port), OptimizerHandler)
    server.session_token = token
    server.candidates = candidates
    server.source_meta = metadata
    server.current_ips = _read_current_ips(args.current_file)
    server.latency_max = args.latency_max
    server.speed_min = args.speed_min
    server.top_count = args.top
    server.test_port = args.test_port if args.test_port in CF_HTTPS_PORTS else 443
    server.candidate_limit = args.candidate_limit
    server.cache_dir = args.cache_dir
    server.result_file = args.result_file
    server.seed = args.seed
    server.cancelled = False
    server.applied = False
    server.verbose = args.verbose
    server.client_results = []
    server.client_test_ip = None
    server.vps_retry_results = []
    server.vps_job = None
    server.vps_meta = {"ip": args.public_host, "region": args.server_place or "未设置地区"}
    server.preview_secret = secrets.token_bytes(32)
    server.preview = None
    server.lock = threading.RLock()
    public_port = args.public_port or server.server_address[1]
    url = f"http://{_display_host(args.public_host)}:{public_port}/{token}/"
    print("\n请用需要优化的电脑/手机网络打开：")
    print(url)
    print(f"\n会话 {args.timeout // 60} 分钟后自动关闭；客户端榜与 VPS 榜分别输出。")
    print("网页确认替换预览并点击应用后，SSH 会自动继续。", flush=True)
    timer = threading.Timer(args.timeout, server.shutdown)
    timer.daemon = True
    timer.start()
    try:
        server.serve_forever(poll_interval=0.25)
    except KeyboardInterrupt:
        server.cancelled = True
    finally:
        timer.cancel()
        if server.vps_job:
            server.vps_job.cancel_event.set()
        server.server_close()
    if server.applied:
        return 0
    if server.cancelled:
        return 2
    print("测速会话已超时，未修改 Lun 配置。", file=sys.stderr)
    return 3


def extract_result(args):
    try:
        data = json.loads(Path(args.result_file).read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as error:
        print(f"无法读取结果：{error}", file=sys.stderr)
        return 1
    selected = data.get("selected", [])
    if args.format == "ips":
        for item in selected:
            print(item.get("ip", ""))
    else:
        print("编号  优选 IP                         客户端                 VPS                    来源")
        for index, item in enumerate(selected, 1):
            client, vps = item.get("client") or {}, item.get("vps") or {}
            client_text = f"{_number(client.get('latency_ms')):.0f}ms/{_number(client.get('speed_mbps')):.1f}M" if client else "-"
            vps_text = f"{_number(vps.get('latency_ms')):.0f}ms/{_number(vps.get('speed_mbps')):.1f}M" if vps else "-"
            print(f"{index:>2}    {item.get('ip', ''):<31} {client_text:<22} {vps_text:<22} {item.get('source') or '-'}")
    return 0 if selected else 1


def build_parser():
    parser = argparse.ArgumentParser(description="Lun 一键优选 CDN 节点")
    parser.add_argument("--version", action="version", version=VERSION)
    sub = parser.add_subparsers(dest="command", required=True)
    run = sub.add_parser("serve", help="启动一次性双向测速页")
    run.add_argument("--bind", default="0.0.0.0")
    run.add_argument("--port", type=int, required=True)
    run.add_argument("--public-host", required=True)
    run.add_argument("--public-port", type=int, default=0)
    run.add_argument("--result-file", required=True)
    run.add_argument("--current-file")
    run.add_argument("--server-place", default="")
    run.add_argument("--cache-dir")
    run.add_argument("--source-key", default=DEFAULT_SOURCE_KEY, choices=tuple(SOURCES))
    run.add_argument("--source-file")
    run.add_argument("--candidate-limit", type=int, default=512, choices=range(1, MAX_CANDIDATES + 1))
    run.add_argument("--top", type=int, default=5, choices=range(1, MAX_SELECTED + 1))
    run.add_argument("--latency-max", type=float, default=150.0)
    run.add_argument("--speed-min", type=float, default=80.0)
    run.add_argument("--test-port", type=int, default=443)
    run.add_argument("--timeout", type=int, default=900, choices=range(60, 3601))
    run.add_argument("--token")
    run.add_argument("--seed", type=int)
    run.add_argument("--verbose", action="store_true")
    run.set_defaults(func=serve)
    extract = sub.add_parser("extract", help="读取优选结果")
    extract.add_argument("--result-file", required=True)
    extract.add_argument("--format", choices=("ips", "table"), default="table")
    extract.set_defaults(func=extract_result)
    return parser


def main(argv=None):
    args = build_parser().parse_args(argv)
    if getattr(args, "cache_dir", None) is None:
        args.cache_dir = str(Path.home() / "lun" / "modules" / "cdnopt" / "cache")
    try:
        return args.func(args)
    except (OSError, ValueError, urllib.error.URLError) as error:
        print(f"错误：{error}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
