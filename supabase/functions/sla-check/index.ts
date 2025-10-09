// supabase/functions/sla-check/index.ts
// Hourly SLA check: scans edge_op_slo_24h and posts to Slack when thresholds breached.
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const url = Deno.env.get("SUPABASE_URL")!;
const key = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
const SLACK = Deno.env.get('SLACK_WEBHOOK_URL');
const OP_MAX_ERR = Number(Deno.env.get('OP_MAX_ERR') ?? 0.01); // 1%
const OP_MAX_P95 = Number(Deno.env.get('OP_MAX_P95') ?? 800);  // ms

const db = createClient(url, key, { auth: { persistSession: false } });

Deno.serve(async (_req) => {
  const { data, error } = await db.from('edge_op_slo_24h').select('op,calls,error_rate,p95_ms');
  if (error) return new Response(JSON.stringify({ ok:false, error: error.message }), { status: 500 });

  const bad = (data ?? []).filter((r: any) => (r.error_rate ?? 0) > OP_MAX_ERR || (r.p95_ms ?? 0) > OP_MAX_P95);
  if (bad.length && SLACK) {
    const text = 'SLA breach(s):\n' + bad.map((b: any) =>
      `• ${b.op} — err ${((b.error_rate ?? 0)*100).toFixed(2)}% p95 ${b.p95_ms}ms (${b.calls} calls)`
    ).join('\n');
    try {
      await fetch(SLACK, { method: 'POST', headers: { 'Content-Type':'application/json' }, body: JSON.stringify({ text }) });
    } catch (_) { /* ignore */ }
  }
  return new Response(JSON.stringify({ ok:true, checked: data?.length ?? 0, breaches: bad.length }), { status: 200 });
});
