// supabase/functions/delay_risk_batch/index.ts
// Edge Function: Delay Risk Batch (optional MVP)
// Accepts array of items, returns array of risks in same order.

import { serve } from 'https://deno.land/std@0.224.0/http/server.ts'

serve(async (req: Request) => {
  const start = performance.now();
  const reqId = crypto.randomUUID();
  try {
    const body = await req.json();
    const items = Array.isArray(body?.items) ? body.items : [];
    const orgId = body.org_id || req.headers.get('x-app-org-id') || items[0]?.org_id;
    if (!orgId) return new Response(JSON.stringify({ error: 'org_id required' }), { status: 400 });

    const results = items.map((_it: any) => ({
      on_time_prob: 0.9,
      late_risk_score: 10,
      risk_bucket: 'low',
      late_risk_reason: 'Normal conditions',
      mitigations: [],
      freshness_seconds: Math.max(5, Math.round((performance.now() - start) / 1000)),
      confidence: 0.6,
    }));

    console.log(JSON.stringify({ span: 'delay_risk.fetch', kind: 'batch', org_id: orgId, visible_count: items.length, req_id: reqId, latency_ms: Math.round(performance.now() - start) }));

    return new Response(JSON.stringify({ data: results }), { headers: { 'Content-Type': 'application/json' } });
  } catch (e) {
    console.error(JSON.stringify({ span: 'delay_risk.fetch', kind: 'batch', error: String(e), req_id: reqId }));
    return new Response(JSON.stringify({ error: 'Bad request' }), { status: 400 });
  }
});
