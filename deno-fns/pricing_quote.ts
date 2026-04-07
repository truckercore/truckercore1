// deno-fns/pricing_quote.ts
// Endpoint: POST /pricing/quote { org_id, lane_key, miles, base_inputs }
// Computes a dynamic price using pricing_rules precedence: lane -> customer -> carrier -> global
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const URL = Deno.env.get("SUPABASE_URL")!;
const KEY = Deno.env.get("SUPABASE_SERVICE_ROLE")!;
const db = createClient(URL, KEY, { auth: { persistSession: false }});

type Rule = { scope: string; key: string; rule: any };

function pickRule(rules: Rule[], laneKey?: string, customerId?: string, carrierId?: string): any | null {
  const priority: Array<{ s: string; k?: string | undefined | null }> = [
    { s: 'lane', k: laneKey },
    { s: 'customer', k: customerId },
    { s: 'carrier', k: carrierId },
    { s: 'global', k: '*' },
  ];
  for (const p of priority) {
    const r = rules.find(x => x.scope === p.s && (p.k ? x.key === p.k : x.scope === 'global'));
    if (r) return r.rule;
  }
  return null;
}

function computePrice(miles: number, rule: any) {
  const base = Number(rule?.base_usd_per_mi ?? 2.25);
  const fuelPct = Number(rule?.fuel_surcharge_pct ?? 0);
  const minUsd = Number(rule?.min_usd ?? 0);
  const rate = base * miles;
  const fuel = Math.round(rate * (fuelPct / 100));
  const total = Math.max(Math.round(rate + fuel), Math.round(minUsd));
  return { usd_per_mi: base, fuel_surcharge_pct: fuelPct, min_usd: minUsd, fuel_usd: fuel, total_usd: total };
}

Deno.serve(async (req) => {
  try {
    if (req.method !== 'POST') return new Response('Method Not Allowed', { status: 405 });
    const b = await req.json().catch(() => ({} as any));
    const orgId = String(b.org_id || '');
    const laneKey = b.lane_key ? String(b.lane_key) : undefined;
    const miles = Number(b.miles || 0);
    const customerId = b.customer_id ? String(b.customer_id) : undefined;
    const carrierId = b.carrier_id ? String(b.carrier_id) : undefined;
    if (!orgId || !Number.isFinite(miles)) return new Response(JSON.stringify({ error: 'bad_request' }), { status: 400, headers: { 'content-type': 'application/json' } });

    const { data, error } = await db
      .from('pricing_rules')
      .select('scope,key,rule')
      .eq('org_id', orgId)
      .eq('active', true)
      .lte('starts_at', new Date().toISOString())
      .or('ends_at.is.null,ends_at.gt.' + new Date().toISOString());
    if (error) return new Response(JSON.stringify({ error: error.message }), { status: 500, headers: { 'content-type': 'application/json' } });

    const rules = (data || []) as Rule[];
    const matched = pickRule(rules, laneKey, customerId, carrierId);
    const breakdown = computePrice(miles, matched);
    return new Response(JSON.stringify(breakdown), { headers: { 'content-type': 'application/json' } });
  } catch (e) {
    return new Response(String((e as any)?.message || e), { status: 400 });
  }
});
