// deno-fns/metrics/heartbeat.mjs
// Endpoint: /metrics/heartbeat — returns sliding 15m p50/p95 and SLO breach flag
// Env:
//   HEARTBEAT_SLO_MS (default 250)
// Notes: Minimal endpoint; add DB/cache pings as needed inside the timed section.

const SLO_MS = Number(Deno.env.get('HEARTBEAT_SLO_MS') ?? 250)

let samples = [] // { v: ms, t: epoch_ms }

function nowMs() { return performance.now() }
function pct(arr, p) {
  if (!arr.length) return 0
  const a = [...arr].sort((x, y) => x - y)
  const i = Math.floor((p / 100) * a.length)
  return a[Math.min(i, a.length - 1)]
}
function gc() {
  const cutoff = Date.now() - 15 * 60 * 1000
  samples = samples.filter((s) => s.t >= cutoff)
}

Deno.serve(async (_req) => {
  const t0 = nowMs()
  // Lightweight internal check(s) can be placed here (e.g., fetch a warm local cache or an in-memory op)
  // For now, we just measure the overhead of the request cycle itself.
  const t1 = nowMs()
  samples.push({ v: t1 - t0, t: Date.now() })
  gc()
  const vals = samples.map((s) => s.v)
  const p50 = pct(vals, 50)
  const p95 = pct(vals, 95)
  const body = {
    p50_ms: Math.round(p50),
    p95_ms: Math.round(p95),
    window_min: 15,
    slo_ms: SLO_MS,
    slo_breaching: Math.round(p95) > SLO_MS,
  }
  return new Response(JSON.stringify(body), {
    headers: {
      'content-type': 'application/json',
      'cache-control': 'no-store',
    },
  })
})
