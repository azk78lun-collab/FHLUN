const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');
const source = fs.readFileSync(path.join(__dirname, '..', 'lun_cdn_optimizer.py'), 'utf8');
function extract(name) {
  const pattern = new RegExp(`(?:async )?function ${name}\\(`);
  const start = source.search(pattern);
  assert(start >= 0, `missing ${name}`);
  const rest = source.slice(start);
  const next = rest.slice(1).search(/\n(?:async )?function /);
  return next < 0 ? rest : rest.slice(0, next + 1);
}
function context() {
  const ctx = vm.createContext({
    AbortController, DOMException, setTimeout, clearTimeout,
    performance: { now: () => Date.now() },
    state: { controllers: new Set(), cancelled: false, helper: 'test' },
    candidatePort: () => 8443, probeUrl: () => 'https://fixture.test/',
    helperLatency: async () => { throw Error('blocked'); }, directLatency: async () => 10,
  });
  vm.runInContext(['abortable', 'pool', 'clientLatency', 'clientSpeed'].map(extract).join('\n'), ctx);
  return ctx;
}
function stalled(ctx) {
  let finish;
  ctx.fetch = async () => ({ ok: true, body: { getReader: () => ({
    read: () => new Promise(resolve => { finish = resolve; }),
    cancel: async () => finish?.({ done: true }),
  }) } });
}
async function main() {
  let ctx = context(); stalled(ctx);
  const started = Date.now();
  await assert.rejects(ctx.clientSpeed({ helper: 'test' }, { downloadBytes: 1024, speedTimeout: .03 }), /超时|取消/);
  assert(Date.now() - started < 400);
  assert.equal(ctx.state.controllers.size, 0);

  ctx = context(); stalled(ctx);
  const pending = assert.rejects(ctx.clientSpeed({ helper: 'test' }, { downloadBytes: 1024, speedTimeout: 1 }), /超时|取消/);
  await new Promise(resolve => setTimeout(resolve, 10));
  assert.equal(ctx.state.controllers.size, 1, 'controller must survive response headers');
  ctx.state.controllers.forEach(controller => controller.abort());
  await pending;
  assert.equal(ctx.state.controllers.size, 0);

  ctx = context(); let cancelled = 0, tick = -100;
  ctx.performance.now = () => tick += 100;
  ctx.fetch = async () => ({ ok: true, body: { getReader: () => ({
    read: async () => ({ done: false, value: new Uint8Array(8192) }),
    cancel: async () => { cancelled++; },
  }) } });
  const speed = await ctx.clientSpeed({ helper: 'test' }, { downloadBytes: 1024, speedTimeout: 1 });
  assert(Math.abs(speed.speed_mbps - .08192) < .00001, 'only requested bytes may count');
  assert.equal(cancelled, 1);

  ctx = context(); ctx.state.helper = null;
  const http = await ctx.clientLatency({ ip: '1.1.1.1' }, { timeoutMs: 100 });
  assert.equal(http.port, 80); assert.equal(http.requested_port, 8443);
  assert.equal(http.probe_protocol, 'http'); assert(http.direct_only);
  assert.match(http.status, /HTTPS 8443 未验证/);
  ctx = context(); let tries = 0;
  ctx.helperLatency = async () => { if (tries++) throw Error('blocked'); return { elapsed: 50, meta: {}, helper: 'test' }; };
  const mixed = await ctx.clientLatency({ ip: '1.1.1.1' }, { timeoutMs: 100 });
  assert.equal(mixed.latency_ms, 50, 'HTTP fallback must not lower measured TLS latency');
  assert.equal(mixed.port, 8443); assert.equal(mixed.probe_protocol, 'https');

  ctx = context(); let active = 0, maximum = 0;
  await ctx.pool(Array.from({ length: 32 }), 16, async () => {
    maximum = Math.max(maximum, ++active);
    await new Promise(resolve => setTimeout(resolve, 10)); active--;
  });
  assert.equal(maximum, 16);
  console.log('6 browser deadline/cancellation/limit/protocol/concurrency scenarios passed');
}
main().catch(error => { console.error(error); process.exitCode = 1; });
