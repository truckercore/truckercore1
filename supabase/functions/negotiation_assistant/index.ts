// supabase/functions/negotiation_assistant/index.ts
// Negotiation assistant v1
// Input: { load_id, lane:{origin,dest}, equipment, current_offer_cpm, broker_id, user_id, context:{market_cpm_p50, market_cpm_p80, trust_score, seasonality} }
// Output: { recommended_cpm, likelihood, bounds:{min,max}, rationale: string[], template: string, trace_id }

import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
const sb = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY, { auth: { persistSession: false } });

function clamp(n: number, a: number, b: number) { return Math.max(a, Math.min(b, n)); }

Deno.serve(async (req) => {
  const traceId = req.headers.get('trace_id') || req.headers.get('x-request-id') || crypto.randomUUID();
  try {
    const b = await req.json();
    const ctx = b?.context ?? {};
    const p50 = Number(ctx.market_cpm_p50 ?? 2.3);
    const p80 = Number(ctx.market_cpm_p80 ?? 2.8);
    const trust = Number(ctx.trust_score ?? 70);
    const seasonality = String(ctx.seasonality ?? 'normal');
    const current = Number(b?.current_offer_cpm ?? p50);

    // Heuristic recommendation: midpoint between p50 and p80, adjusted by trust and seasonality
    let rec = (p50 + p80) / 2;
    if (trust >= 80) rec -= 0.05; // strong relationship, slightly lower acceptable
    if (seasonality === 'high') rec += 0.1; // peak season adds price power

    // Keep within bounds [p50-0.2, p80+0.2]
    const min = Math.max(1.0, p50 - 0.2);
    const max = Math.max(min + 0.1, p80 + 0.2);
    rec = clamp(rec, min, max);

    // Acceptance likelihood heuristic: higher if rec closer to p50 and trust high
    const span = Math.max(0.01, p80 - p50);
    const pos = clamp(1 - ((rec - p50) / span), 0, 1); // 1 at p50, 0 at p80
    let likelihood = 0.4 + 0.4 * pos + (trust - 50) / 500; // 0.4..0.95 typical
    likelihood = clamp(likelihood, 0.05, 0.95);

    const rationale: string[] = [];
    if (rec > current) rationale.push(`+${((rec - current) / Math.max(0.01,current)) > 0 ? ((rec - current)/current*100).toFixed(0) : '0'}% vs current offer`);
    const deltaVsMarket = ((rec - p50) / Math.max(0.01, p50));
    rationale.push(`${(deltaVsMarket*100 >= 0 ? '+' : '')}${(deltaVsMarket*100).toFixed(0)}% vs market P50`);
    if (trust >= 80) rationale.push('Broker trust high');
    if (seasonality === 'high') rationale.push('Seasonality peak');

    const template = "Hi {{broker}}, we can do {{rate}} CPM with pickup {{window}}. On-time {{on_time_prob}}%. Thanks!";

    return new Response(JSON.stringify({
      recommended_cpm: Number(rec.toFixed(2)),
      likelihood: Number(likelihood.toFixed(2)),
      bounds: { min: Number(min.toFixed(2)), max: Number(max.toFixed(2)) },
      rationale,
      template,
      trace_id: traceId,
    }), { headers: { 'content-type': 'application/json', 'trace_id': traceId } });
  } catch (e) {
    return new Response(JSON.stringify({ error: String(e), trace_id: traceId }), { status: 500, headers: { 'content-type': 'application/json', 'trace_id': traceId } });
  }
});
