// supabase/functions/edge-log-watchdog/index.ts
// Edge Log Watchdog: checks retention, partition readiness, and drift via DB view
// Posts to a webhook on breach with anti-flap suppression using Deno KV.

import { getServiceClient } from "../_shared/client.ts";

const WEBHOOK = Deno.env.get('OPS_WEBHOOK_URL') || '';
const RUNBOOK = Deno.env.get('OPS_RUNBOOK_URL') || Deno.env.get('OPS_RUNBOOK') || 'https://ops/runbooks';
const SUPPRESS_MINUTES = (() => {
  const w = Deno.env.get('WATCHDOG_SUPPRESS_MIN');
  if (w) return Number(w);
  const a = Deno.env.get('ALERT_SUPPRESS_MIN');
  if (a) return Number(a);
  const env = (Deno.env.get('ENV') || Deno.env.get('NODE_ENV') || '').toLowerCase();
  return (env === 'prod' || env === 'production') ? 30 : 5;
})();

const kv = await Deno.openKv();

function json(data: unknown, status = 200) {
  return new Response(JSON.stringify(data), { status, headers: { 'content-type': 'application/json' } });
}

function breached(d: any) {
  return !(d.retention_ok && d.oldest_within_30d && d.next_partition_present);
}

async function shouldNotify(key: string) {
  const now = Date.now();
  const last = (await kv.get<number>([key])).value ?? 0;
  if (now - last < SUPPRESS_MINUTES * 60_000) return false;
  await kv.set([key], now);
  return true;
}

export default Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: { 'access-control-allow-origin': '*' } });

  const adminClient = getServiceClient();
  const { data, error } = await adminClient
    .from('edge_log_watchdog')
    .select('*')
    .single();

  if (error) {
    return json({ ok: false, error: error.message }, 500);
  }

  const ok = !breached(data as any);

  if (!ok && WEBHOOK && (await shouldNotify('edge_log_watchdog'))) {
    const d = data as any;
    const msg = [
      '*Edge log watchdog* ❗',
      `retention_ok=${d.retention_ok}`,
      `oldest_within_30d=${d.oldest_within_30d}`,
      `next_partition_present=${d.next_partition_present}`,
      `rows_beyond_30d=${d.rows_beyond_30d}`,
      `last_maintenance_ok=${d.last_maintenance_ok}`,
      `maintenance_lag=${d.maintenance_lag}`,
      `drift_signal=${d.drift_signal}`,
      `err_rate_7d=${(d.error_rate_7d ?? 0).toFixed ? (d.error_rate_7d ?? 0).toFixed(3) : String(d.error_rate_7d)}`,
      `err_rate_prev7=${(d.error_rate_prev7 ?? 0).toFixed ? (d.error_rate_prev7 ?? 0).toFixed(3) : String(d.error_rate_prev7)}`,
      RUNBOOK ? `runbook: ${RUNBOOK}` : ''
    ].filter(Boolean).join('\n');

    try {
      await fetch(WEBHOOK, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ text: msg })
      });
    } catch (_) {
      // ignore webhook errors
    }
  }

  return json({ ok, data }, ok ? 200 : 500);
});
