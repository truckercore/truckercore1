// deno-fns/market_match.ts
// Endpoint: POST /market/match { org_id, load_id, lane_key?, candidates? }
// Returns ranked carriers/fleets using trust score, simple proximity/lane fit (placeholder), recent activity, and incentives.
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const URL = Deno.env.get("SUPABASE_URL")!;
const KEY = Deno.env.get("SUPABASE_SERVICE_ROLE")!;
const db = createClient(URL, KEY, { auth: { persistSession: false }});

type TrustRow = { actor_id: string; score: number; factors?: any };

deno:
Deno.serve(async (req) => {
  try {
    if (req.method !== 'POST') return new Response('Method Not Allowed', { status: 405 });
    const b = await req.json().catch(() => ({} as any));
    const orgId = String(b.org_id || '');
    const laneKey = b.lane_key ? String(b.lane_key) : undefined;
    if (!orgId) return new Response(JSON.stringify({ error: 'bad_request' }), { status: 400, headers: { 'content-type': 'application/json' } });

    // Load trust scores for carriers/fleets
    const { data: trustData } = await db
      .from('market_trust')
      .select('actor_id, score, factors')
      .eq('org_id', orgId);

    // Load incentives for boost
    const { data: incData } = await db
      .from('liquidity_incentives')
      .select('actor_id, value_cents, incentive_type')
      .eq('org_id', orgId)
      .eq('side', 'fleet');

    const incMap = new Map<string, number>();
    for (const r of (incData || []) as any[]) {
      const key = String(r.actor_id);
      const val = Number(r.value_cents || 0);
      incMap.set(key, (incMap.get(key) || 0) + val);
    }

    // Rank function: trust (0..1) * 0.7 + incentive boost normalized * 0.3
    const maxBoost = Math.max(1, ...Array.from(incMap.values()));
    const rows: Array<{ actor_id: string; score: number; badges: string[] }> = [];
    for (const t of (trustData || []) as TrustRow[]) {
      const boost = (incMap.get(String(t.actor_id)) || 0) / maxBoost;
      const trust = Math.max(0, Math.min(1, Number(t.score || 0.5)));
      let s = 0.7 * trust + 0.3 * boost;
      const badges: string[] = [];
      if (trust >= 0.8) badges.push('high_trust');
      if (boost > 0) badges.push('incentivized');
      if (laneKey) badges.push('lane_fit'); // placeholder flag
      rows.push({ actor_id: String(t.actor_id), score: Math.round(s * 100) / 100, badges });
    }

    rows.sort((a, b) => b.score - a.score);
    return new Response(JSON.stringify({ matches: rows.slice(0, 20) }), { headers: { 'content-type': 'application/json' } });
  } catch (e) {
    return new Response(String((e as any)?.message || e), { status: 400 });
  }
});
