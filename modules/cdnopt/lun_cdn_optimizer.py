#!/usr/bin/env python3
"""Lun on-demand Cloudflare edge optimizer.

The VPS only serves a short-lived page and validates the returned data.  The
browser performs the measurements because the useful path is client ->
Cloudflare edge, not VPS -> Cloudflare edge.
"""

from __future__ import annotations

import argparse
import ipaddress
import json
import os
import random
import secrets
import sys
import threading
import time
import urllib.error
import urllib.request
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
from urllib.parse import urlsplit


VERSION = "1.1.0"
DEFAULT_SOURCE = "https://raw.githubusercontent.com/cmliu/cmliu/main/CF-CIDR.txt"
MAX_SOURCE_BYTES = 1024 * 1024
MAX_REQUEST_BYTES = 2 * 1024 * 1024


def _number(value, default=0.0):
    try:
        number = float(value)
    except (TypeError, ValueError):
        return default
    if number != number or number in (float("inf"), float("-inf")):
        return default
    return number


def _bounded_threshold(value, default, minimum, maximum, label):
    number = _number(value, default)
    if number < minimum or number > maximum:
        raise ValueError(f"{label}必须在 {minimum:g}-{maximum:g} 之间")
    return number


def rank_results(measurements, candidates, latency_max, speed_min, top_count):
    """Validate, filter, and rank browser measurements.

    Throughput is the dominant signal; latency applies a modest penalty.  This
    keeps a slightly farther but much faster edge ahead of a nearby slow edge.
    """

    allowed = {str(ipaddress.ip_address(item)) for item in candidates}
    accepted = []
    seen = set()
    for item in measurements if isinstance(measurements, list) else []:
        if not isinstance(item, dict):
            continue
        try:
            address = str(ipaddress.ip_address(str(item.get("ip", "")).strip()))
        except ValueError:
            continue
        if address not in allowed or address in seen:
            continue
        latency = _number(item.get("latency_ms"), -1)
        speed = _number(item.get("speed_mbps"), -1)
        if latency <= 0 or speed <= 0:
            continue
        seen.add(address)
        if latency > latency_max or speed < speed_min:
            continue
        score = speed / (1.0 + latency / 100.0)
        accepted.append(
            {
                "ip": address,
                "latency_ms": round(latency, 1),
                "speed_mbps": round(speed, 2),
                "score": round(score, 3),
                "colo": str(item.get("colo", ""))[:16],
                "country": str(item.get("country", ""))[:16],
                "ip_type": str(item.get("ip_type", ""))[:16],
            }
        )
    accepted.sort(
        key=lambda item: (
            -item["score"],
            -item["speed_mbps"],
            item["latency_ms"],
            item["ip"],
        )
    )
    return accepted[:top_count], accepted


def _clean_source_lines(text):
    entries = []
    for raw in text.splitlines():
        value = raw.split("#", 1)[0].strip()
        if not value:
            continue
        try:
            if "/" in value:
                entries.append(ipaddress.ip_network(value, strict=False))
            else:
                entries.append(ipaddress.ip_address(value))
        except ValueError:
            continue
    if not entries:
        raise ValueError("候选库中没有可用的 IP/CIDR")
    return entries


def _read_source(source, source_file=None):
    if source_file:
        return Path(source_file).read_text(encoding="utf-8")
    parsed = urlsplit(source)
    if parsed.scheme != "https":
        raise ValueError("候选库只允许 HTTPS 地址")
    request = urllib.request.Request(
        source,
        headers={
            "User-Agent": f"Lun-CDN-Optimizer/{VERSION}",
            "Accept": "text/plain",
            "Cache-Control": "no-cache",
        },
    )
    with urllib.request.urlopen(request, timeout=20) as response:
        content = response.read(MAX_SOURCE_BYTES + 1)
    if len(content) > MAX_SOURCE_BYTES:
        raise ValueError("候选库超过 1 MiB，已拒绝")
    return content.decode("utf-8", errors="replace")


def _random_ip(network, rng):
    if network.num_addresses == 1:
        return network.network_address
    low = int(network.network_address)
    high = int(network.broadcast_address)
    if network.version == 4 and network.num_addresses > 2:
        low += 1
        high -= 1
    return ipaddress.ip_address(rng.randint(low, high))


def load_candidates(source, limit, source_file=None, seed=None):
    entries = _clean_source_lines(_read_source(source, source_file))
    rng = random.Random(seed) if seed is not None else secrets.SystemRandom()
    rng.shuffle(entries)
    direct = [entry for entry in entries if not isinstance(entry, (ipaddress.IPv4Network, ipaddress.IPv6Network))]
    networks = [entry for entry in entries if isinstance(entry, (ipaddress.IPv4Network, ipaddress.IPv6Network))]
    candidates = []
    seen = set()

    def add(value):
        value = str(value)
        if value in seen or len(candidates) >= limit:
            return
        seen.add(value)
        candidates.append(value)

    for entry in direct:
        add(entry)
    attempts = 0
    max_attempts = max(limit * 20, len(networks) * 10)
    while networks and len(candidates) < limit and attempts < max_attempts:
        add(_random_ip(networks[attempts % len(networks)], rng))
        attempts += 1
    if not candidates:
        raise ValueError("未能生成候选 IP")
    return candidates


def _atomic_json(path, data):
    target = Path(path)
    target.parent.mkdir(parents=True, exist_ok=True)
    temporary = target.with_name(f".{target.name}.tmp.{os.getpid()}")
    with temporary.open("w", encoding="utf-8") as handle:
        json.dump(data, handle, ensure_ascii=False, indent=2)
        handle.write("\n")
    os.chmod(temporary, 0o600)
    os.replace(temporary, target)
    os.chmod(target, 0o600)


PAGE = r'''<!doctype html>
<html lang="zh-CN">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
<title>Lun 一键优选 CDN 节点</title>
<style>
:root{color-scheme:dark;--bg:#090b10;--panel:#111622;--line:#273044;--text:#edf2ff;--muted:#98a6bd;--cyan:#27d8d1;--orange:#ff9d2f;--green:#42db75;--red:#ff6472}
*{box-sizing:border-box}body{margin:0;background:radial-gradient(circle at 20% 0,#10202c 0,transparent 34%),var(--bg);color:var(--text);font:15px/1.55 system-ui,-apple-system,"Segoe UI",sans-serif}.wrap{max-width:1040px;margin:auto;padding:24px}.hero,.panel{background:rgba(17,22,34,.94);border:1px solid var(--line);border-radius:16px;padding:20px;margin-bottom:16px;box-shadow:0 18px 55px #0007}.hero h1{margin:0 0 6px;font-size:28px}.hero h1 span{color:var(--cyan)}.muted{color:var(--muted)}.stats{display:grid;grid-template-columns:repeat(4,1fr);gap:10px;margin-top:16px}.stat{padding:12px;border:1px solid var(--line);border-radius:12px;background:#0c111b}.stat b{display:block;font-size:20px;color:var(--orange)}button{border:0;border-radius:10px;padding:11px 18px;font-weight:700;cursor:pointer;background:linear-gradient(135deg,var(--cyan),#3f92ff);color:#031016}button.secondary{background:#222b3c;color:var(--text)}button.danger{background:#3a1e25;color:#ffb3ba}button:disabled{opacity:.45;cursor:not-allowed}.actions{display:flex;gap:10px;flex-wrap:wrap;align-items:center}.thresholds{display:flex;gap:12px;flex-wrap:wrap;margin:12px 0}.thresholds label{color:var(--muted)}input[type=number]{width:118px;margin-left:6px;padding:8px 9px;border-radius:8px;border:1px solid var(--line);background:#090d16;color:var(--text)}.progress{height:10px;background:#080b12;border-radius:999px;overflow:hidden;margin:14px 0}.bar{height:100%;width:0;background:linear-gradient(90deg,var(--cyan),var(--orange));transition:width .2s}.status{min-height:24px}.ok{color:var(--green)}.bad{color:var(--red)}table{width:100%;border-collapse:collapse;margin-top:12px;font-variant-numeric:tabular-nums}th,td{text-align:left;padding:9px 8px;border-bottom:1px solid var(--line)}th{color:var(--muted);font-size:12px}.pill{display:inline-block;padding:2px 7px;border-radius:999px;background:#173428;color:var(--green);font-size:12px}.notice{border-left:3px solid var(--orange);padding:10px 12px;background:#241b11;border-radius:7px;margin:12px 0}.credit{font-size:12px;color:var(--muted);margin-top:16px}.credit a{color:var(--cyan)}@media(max-width:720px){.wrap{padding:12px}.stats{grid-template-columns:repeat(2,1fr)}th:nth-child(5),td:nth-child(5){display:none}}
</style>
</head>
<body><main class="wrap">
<section class="hero"><h1><span>Lun</span> · 一键优选 CDN 节点</h1><div class="muted">测试由当前浏览器所在的网络执行，结果代表“您的设备 → Cloudflare 边缘”，不是 VPS 的 ping。</div>
<div class="stats"><div class="stat"><b id="candidateCount">-</b>待测 IP</div><div class="stat"><b id="latencyMax">-</b>最大延迟</div><div class="stat"><b id="speedMin">-</b>最低带宽</div><div class="stat"><b id="topCount">-</b>返回数量</div></div></section>
<section class="panel"><div class="notice">测速会产生下载流量，默认只对延迟合格的少量候选节点进行带宽测试。请关闭代理/VPN，用实际需要优化的网络打开本页。</div>
<div class="thresholds"><label>最大延迟 <input id="latencyInput" type="number" min="1" max="3000" step="1"> ms</label><label>最低带宽 <input id="speedInput" type="number" min="0.1" max="10000" step="0.1"> Mbps</label></div>
<div class="actions"><button id="start">开始综合优选</button><button id="apply" disabled>应用前 <span id="applyCount">0</span> 个到 Lun</button><button class="danger" id="cancel">取消并关闭</button></div>
<div class="progress"><div class="bar" id="bar"></div></div><div class="status" id="status">正在读取候选库……</div></section>
<section class="panel"><strong>综合结果</strong><span class="muted">（速度为主，延迟进行适度惩罚）</span><table><thead><tr><th>#</th><th>IP</th><th>数据中心</th><th>延迟</th><th>速度</th><th>结果</th></tr></thead><tbody id="rows"><tr><td colspan="6" class="muted">尚未测速</td></tr></tbody></table>
<div class="credit">候选库来自 <a href="https://github.com/cmliu/cmliu" target="_blank" rel="noopener">CM IP</a>；在线探测协议参考 <a href="https://github.com/cmliu/edgetunnel" target="_blank" rel="noopener">cmliu/edgetunnel</a> 与 BestCF，感谢 HiDNS、@ktff、@Lfreea 的探索与贡献。</div></section>
</main>
<script>
const $=s=>document.querySelector(s);let cfg=null,measurements=[],ranked=[],cancelled=false,states=new Map();const activeControllers=new Set();
const esc=v=>String(v).replace(/[&<>"']/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]));
function tokenPath(s){return location.pathname.replace(/\/$/,'')+'/'+s}
function probeUrl(ip,path,params={}){const label=ip.includes(':')?ip.toLowerCase().replaceAll(':','-'):ip.split('.').map(v=>(+v).toString(16).padStart(2,'0')).join('').toUpperCase();const q=new URLSearchParams({_t:Date.now().toString(),...params});return `https://${label}.bestcf.cmliussss.hidns.vip:${cfg.test_port}/${path}?${q}`}
async function timedFetch(url,opt={},ms=3000){const c=new AbortController(),t=setTimeout(()=>c.abort(),ms);activeControllers.add(c);try{return await fetch(url,{...opt,cache:'no-store',signal:c.signal})}finally{clearTimeout(t);activeControllers.delete(c)}}
async function pool(items,n,fn,onDone){let next=0,done=0;async function worker(){while(!cancelled){const i=next++;if(i>=items.length)return;await fn(items[i],i).catch(()=>{});done++;onDone(done,items.length)}}await Promise.all(Array.from({length:Math.min(n,items.length)},worker))}
async function latencyTest(ip){const url=probeUrl(ip,'ip.json');try{await timedFetch(url,{method:'OPTIONS'},2500)}catch(e){}const start=performance.now();const r=await timedFetch(url,{},Math.max(3000,cfg.latency_max*8));if(!r.ok)throw Error('HTTP');const d=await r.json();return {ip,latency_ms:Math.max(1,performance.now()-start),speed_mbps:0,colo:d.colo||'',country:d.country||'',ip_type:d.ipType||''}}
function diverseFinalists(items,limit){const groups=new Map();for(const x of [...items].sort((a,b)=>a.latency_ms-b.latency_ms)){const k=x.colo||'unknown';if(!groups.has(k))groups.set(k,[]);groups.get(k).push(x)}const out=[];while(out.length<limit){let moved=false;for(const list of groups.values()){if(list.length&&out.length<limit){out.push(list.shift());moved=true}}if(!moved)break}return out}
async function speedTest(item){const started=performance.now();let bytes=0;const c=new AbortController(),timer=setTimeout(()=>c.abort(),cfg.speed_timeout_ms);activeControllers.add(c);try{const r=await fetch(probeUrl(item.ip,'__down',{bytes:String(cfg.download_bytes)}),{cache:'no-store',signal:c.signal});if(!r.ok)throw Error('HTTP');if(r.body&&r.body.getReader){const reader=r.body.getReader();while(true){const p=await reader.read();if(p.done)break;bytes+=p.value.byteLength}}else{bytes=(await r.arrayBuffer()).byteLength}}catch(e){if(!bytes)throw e}finally{clearTimeout(timer);activeControllers.delete(c)}const seconds=Math.max(.001,(performance.now()-started)/1000);item.speed_mbps=bytes*8/seconds/1000000;return item}
function score(x){return x.speed_mbps/(1+x.latency_ms/100)}
function setState(ip,patch){states.set(ip,{...(states.get(ip)||{ip,status:'等待延迟'}),...patch});render()}
function render(){const done=measurements.filter(x=>x.speed_mbps>0).sort((a,b)=>score(b)-score(a)||b.speed_mbps-a.speed_mbps||a.latency_ms-b.latency_ms);ranked=done.filter(x=>x.latency_ms<=cfg.latency_max&&x.speed_mbps>=cfg.speed_min).slice(0,cfg.top_count);const selected=new Set(ranked.map(x=>x.ip));const order={'入选':0,'测速中':1,'延迟合格':2,'延迟完成':3,'等待延迟':4,'未达标':5,'失败':6};const rows=[...states.values()].sort((a,b)=>(order[a.status]??9)-(order[b.status]??9)||(a.latency_ms||99999)-(b.latency_ms||99999));$('#rows').innerHTML=rows.length?rows.map((x,i)=>{let status=x.status||'-';if(selected.has(x.ip))status='<span class="pill">入选</span>';return `<tr><td>${i+1}</td><td><code>${esc(x.ip)}</code></td><td>${esc(x.colo||'-')}</td><td>${x.latency_ms?x.latency_ms.toFixed(0)+' ms':'-'}</td><td>${x.speed_mbps?x.speed_mbps.toFixed(1)+' Mbps':'-'}</td><td>${status}</td></tr>`}).join(''):'<tr><td colspan="6" class="muted">尚未测速</td></tr>';$('#applyCount').textContent=ranked.length;$('#apply').disabled=!ranked.length}
function progress(done,total,text){if(cancelled)return;$('#bar').style.width=(total?done/total*100:0)+'%';$('#status').textContent=text}
async function run(){const lm=Number($('#latencyInput').value),sm=Number($('#speedInput').value);if(!(lm>=1&&lm<=3000&&sm>=.1&&sm<=10000)){progress(0,1,'请输入有效门槛：延迟 1-3000 ms，带宽 0.1-10000 Mbps。');return}cfg.latency_max=lm;cfg.speed_min=sm;$('#latencyMax').textContent=lm+' ms';$('#speedMin').textContent=sm+' Mbps';cancelled=false;measurements=[];ranked=[];states=new Map(cfg.candidates.map(ip=>[ip,{ip,status:'等待延迟'}]));render();$('#start').disabled=true;$('#apply').disabled=true;progress(0,cfg.candidates.length,'正在筛选延迟……');const latency=[];await pool(cfg.candidates,cfg.latency_concurrency,async ip=>{setState(ip,{status:'测速中'});try{const item=await latencyTest(ip);latency.push(item);setState(ip,{...item,status:item.latency_ms<=cfg.latency_max?'延迟合格':'未达标'})}catch(e){setState(ip,{status:'失败'})}},(d,t)=>progress(d,t,`延迟筛选 ${d}/${t}，合格 ${latency.filter(x=>x.latency_ms<=cfg.latency_max).length}`));if(cancelled)return;const eligible=latency.filter(x=>x.latency_ms<=cfg.latency_max);const finalists=diverseFinalists(eligible,cfg.speed_limit);for(const item of eligible){if(!finalists.some(x=>x.ip===item.ip))setState(item.ip,{status:'延迟完成'})}if(!finalists.length){$('#status').innerHTML='<span class="bad">没有延迟合格的 IP，请检查当前网络是否禁止探测域名。</span>';$('#start').disabled=false;return}progress(0,finalists.length,`正在测试 ${finalists.length} 个候选的带宽……`);await pool(finalists,cfg.speed_concurrency,async item=>{setState(item.ip,{status:'测速中'});try{measurements.push(await speedTest(item));setState(item.ip,{...item,status:item.speed_mbps>=cfg.speed_min?'延迟合格':'未达标'})}catch(e){item.speed_mbps=0;measurements.push(item);setState(item.ip,{...item,status:'失败'})}},(d,t)=>progress(d,t,`带宽测试 ${d}/${t}`));if(cancelled)return;render();progress(1,1,ranked.length?`完成：${ranked.length} 个节点达到 ${cfg.latency_max}ms / ${cfg.speed_min}Mbps 门槛。`:'已完成，但没有节点同时达到延迟和带宽门槛。');$('#start').disabled=false}
async function apply(){if(!ranked.length)return;$('#apply').disabled=true;const r=await fetch(tokenPath('apply'),{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify({measurements,latency_max:cfg.latency_max,speed_min:cfg.speed_min})});const data=await r.json();if(!r.ok){$('#status').innerHTML=`<span class="bad">${data.error||'应用失败'}</span>`;$('#apply').disabled=false;return}$('#status').innerHTML=`<span class="ok">已回传并应用 ${data.selected.length} 个节点，可返回 SSH 终端。</span>`;$('#start').disabled=true}
async function cancel(){cancelled=true;for(const c of activeControllers)c.abort();activeControllers.clear();$('#status').textContent='已取消，可关闭本页。';$('#start').disabled=true;$('#apply').disabled=true;try{await fetch(tokenPath('cancel'),{method:'POST'})}catch(e){}}
fetch(tokenPath('config')).then(r=>r.json()).then(data=>{cfg=data;$('#candidateCount').textContent=cfg.candidates.length;$('#latencyMax').textContent=cfg.latency_max+' ms';$('#speedMin').textContent=cfg.speed_min+' Mbps';$('#latencyInput').value=cfg.latency_max;$('#speedInput').value=cfg.speed_min;$('#topCount').textContent=cfg.top_count;states=new Map(cfg.candidates.map(ip=>[ip,{ip,status:'等待延迟'}]));render();$('#status').textContent='候选库已就绪，可先修改门槛，再点击“开始综合优选”。'}).catch(()=>{$('#status').innerHTML='<span class="bad">无法读取测速会话，链接可能已过期。</span>'});
$('#start').onclick=run;$('#apply').onclick=apply;$('#cancel').onclick=cancel;
</script></body></html>'''


class OptimizerServer(ThreadingHTTPServer):
    daemon_threads = True
    allow_reuse_address = True


class OptimizerHandler(BaseHTTPRequestHandler):
    server_version = "LunCDNOptimizer/1"

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
        self.send_header(
            "Content-Security-Policy",
            "default-src 'none'; style-src 'unsafe-inline'; script-src 'unsafe-inline'; "
            "connect-src 'self' https://*.bestcf.cmliussss.hidns.vip:*",
        )
        self.end_headers()

    def _send_bytes(self, status, payload, content_type):
        self._headers(status, content_type, len(payload))
        self.wfile.write(payload)

    def _send_json(self, status, data):
        self._send_bytes(
            status,
            json.dumps(data, ensure_ascii=False).encode("utf-8"),
            "application/json; charset=utf-8",
        )

    def _read_json(self):
        try:
            length = int(self.headers.get("Content-Length", "0"))
        except ValueError:
            raise ValueError("请求长度无效")
        if length <= 0 or length > MAX_REQUEST_BYTES:
            raise ValueError("请求内容为空或过大")
        try:
            return json.loads(self.rfile.read(length).decode("utf-8"))
        except (UnicodeDecodeError, json.JSONDecodeError) as error:
            raise ValueError("JSON 格式无效") from error

    def _finish_later(self):
        threading.Thread(target=self.server.shutdown, daemon=True).start()

    def do_GET(self):
        route = self._route()
        if route is None:
            self._send_json(404, {"error": "not found"})
            return
        if route in ("", "index.html"):
            self._send_bytes(200, PAGE.encode("utf-8"), "text/html; charset=utf-8")
            return
        if route == "config":
            self._send_json(200, self.server.public_config)
            return
        self._send_json(404, {"error": "not found"})

    def do_POST(self):
        route = self._route()
        if route is None:
            self._send_json(404, {"error": "not found"})
            return
        if route == "cancel":
            self.server.cancelled = True
            self._send_json(200, {"ok": True})
            self._finish_later()
            return
        if route != "apply":
            self._send_json(404, {"error": "not found"})
            return
        try:
            request = self._read_json()
            if not isinstance(request, dict):
                raise ValueError("请求内容必须是 JSON 对象")
            latency_max = _bounded_threshold(
                request.get("latency_max"), self.server.latency_max, 1, 3000, "最大延迟"
            )
            speed_min = _bounded_threshold(
                request.get("speed_min"), self.server.speed_min, 0.1, 10000, "最低带宽"
            )
            selected, accepted = rank_results(
                request.get("measurements", []),
                self.server.candidates,
                latency_max,
                speed_min,
                self.server.top_count,
            )
            if not selected:
                self._send_json(
                    422,
                    {
                        "error": f"没有节点同时达到 {latency_max:g}ms / {speed_min:g}Mbps",
                        "accepted": 0,
                    },
                )
                return
            result = {
                "version": VERSION,
                "created_at": int(time.time()),
                "source": self.server.source,
                "latency_max_ms": latency_max,
                "speed_min_mbps": speed_min,
                "requested_top": self.server.top_count,
                "selected": selected,
                "qualified": accepted,
            }
            _atomic_json(self.server.result_file, result)
            self.server.applied = True
            self._send_json(200, {"ok": True, "selected": selected})
            self._finish_later()
        except (OSError, ValueError) as error:
            self._send_json(400, {"error": str(error)})


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
    candidates = load_candidates(args.source, args.candidate_limit, args.source_file, args.seed)
    token = args.token or secrets.token_urlsafe(24)
    server = OptimizerServer((args.bind, args.port), OptimizerHandler)
    server.session_token = token
    server.candidates = candidates
    server.latency_max = args.latency_max
    server.speed_min = args.speed_min
    server.top_count = args.top
    server.source = args.source_file or args.source
    server.result_file = args.result_file
    server.cancelled = False
    server.applied = False
    server.verbose = args.verbose
    speed_limit = min(len(candidates), max(args.top * 4, args.speed_limit))
    server.public_config = {
        "candidates": candidates,
        "latency_max": args.latency_max,
        "speed_min": args.speed_min,
        "top_count": args.top,
        "test_port": args.test_port,
        "latency_concurrency": args.latency_concurrency,
        "speed_concurrency": args.speed_concurrency,
        "speed_limit": speed_limit,
        "download_bytes": args.download_bytes,
        "speed_timeout_ms": args.speed_timeout * 1000,
    }
    public_port = args.public_port or server.server_address[1]
    url = f"http://{_display_host(args.public_host)}:{public_port}/{token}/"
    print("")
    print("请用需要优化的电脑/手机网络打开：")
    print(url)
    print("")
    print(f"会话 {args.timeout // 60} 分钟后自动关闭；返回 {args.top} 个，门槛 {args.latency_max:g}ms / {args.speed_min:g}Mbps。")
    print("保持本终端运行，在网页点击“应用到 Lun”后会自动继续。", flush=True)
    timer = threading.Timer(args.timeout, server.shutdown)
    timer.daemon = True
    timer.start()
    try:
        server.serve_forever(poll_interval=0.25)
    except KeyboardInterrupt:
        server.cancelled = True
    finally:
        timer.cancel()
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
        print("编号  优选 IP                         延迟       带宽        数据中心")
        for index, item in enumerate(selected, 1):
            print(
                f"{index:>2}    {item.get('ip', ''):<31} "
                f"{_number(item.get('latency_ms')):>6.1f} ms  "
                f"{_number(item.get('speed_mbps')):>8.2f} Mbps  "
                f"{item.get('colo') or '-'}"
            )
    return 0 if selected else 1


def build_parser():
    parser = argparse.ArgumentParser(description="Lun 一键优选 CDN 节点")
    parser.add_argument("--version", action="version", version=VERSION)
    sub = parser.add_subparsers(dest="command", required=True)
    run = sub.add_parser("serve", help="启动一次性测速页")
    run.add_argument("--bind", default="0.0.0.0")
    run.add_argument("--port", type=int, required=True)
    run.add_argument("--public-host", required=True)
    run.add_argument("--public-port", type=int, default=0)
    run.add_argument("--result-file", required=True)
    run.add_argument("--source", default=DEFAULT_SOURCE)
    run.add_argument("--source-file")
    run.add_argument("--candidate-limit", type=int, default=256, choices=range(32, 1025))
    run.add_argument("--top", type=int, default=5, choices=range(1, 51))
    run.add_argument("--latency-max", type=float, default=150.0)
    run.add_argument("--speed-min", type=float, default=80.0)
    run.add_argument("--test-port", type=int, default=443)
    run.add_argument("--latency-concurrency", type=int, default=16, choices=range(1, 33))
    run.add_argument("--speed-concurrency", type=int, default=4, choices=range(1, 9))
    run.add_argument("--speed-limit", type=int, default=24, choices=range(5, 101))
    run.add_argument("--download-bytes", type=int, default=10_000_000)
    run.add_argument("--speed-timeout", type=int, default=8, choices=range(2, 31))
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
    try:
        return args.func(args)
    except (OSError, ValueError, urllib.error.URLError) as error:
        print(f"错误：{error}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
