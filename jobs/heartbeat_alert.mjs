// jobs/heartbeat_alert.mjs
// Runs as a minute cron. Fetches heartbeat endpoint and notifies if p95 exceeds SLO.
// Env:
//   HEARTBEAT_URL (required)
//   HEARTBEAT_SLO_MS (default 250)
//   ALERT_WEBHOOK (optional) — if not set, logs to console

const SLO_MS = Number(process.env.HEARTBEAT_SLO_MS ?? 250)

async function notifyP1(text) {
  const webhook = process.env.ALERT_WEBHOOK
  if (!webhook) {
    console.warn('[HEARTBEAT_ALERT]', text)
    return
  }
  try {
    await fetch(webhook, { method: 'POST', headers: { 'content-type': 'application/json' }, body: JSON.stringify({ sev: 'P1', msg: text }) })
  } catch (e) {
    console.warn('[HEARTBEAT_ALERT_FAIL]', e?.message || e)
  }
}

function required(name) {
  const v = process.env[name]
  if (!v) {
    console.error(`Missing env ${name}`)
    process.exit(1)
  }
  return v
}

async function main() {
  const url = required('HEARTBEAT_URL')
  const res = await fetch(url)
  if (!res.ok) throw new Error(`heartbeat_http_${res.status}`)
  const { p95_ms } = await res.json()
  if (typeof p95_ms === 'number' && p95_ms > SLO_MS) {
    await notifyP1(`Heartbeat p95=${p95_ms}ms > SLO ${SLO_MS}ms (15m) — ${url}`)
  } else {
    console.log('[HEARTBEAT_OK]', { p95_ms, slo_ms: SLO_MS })
  }
}

main().catch((e) => { console.error(e); process.exit(1) })
