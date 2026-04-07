// Supabase Edge Function (scheduled): cron.trust_recalc
// Runs nightly to update user_trust based on agreement with later posterior states.

import "jsr:@supabase/functions-js/edge-runtime";
import { createClient } from "npm:@supabase/supabase-js@2";

const URL = Deno.env.get("SUPABASE_URL")!;
const SERVICE = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;

Deno.serve(async (_req) => {
  try {
    const admin = createClient(URL, SERVICE);
    const now = new Date();
    const windowHours = 24; // look back 24h for recalculation
    const sinceIso = new Date(Date.now() - windowHours * 60 * 60 * 1000).toISOString();

    // Fetch reports last 24h and compare to latest state per POI
    const { data: reports } = await admin
      .from('poi_reports')
      .select('user_id, poi_id, kind, status, trust_snapshot, ts')
      .gte('ts', sinceIso);

    const parkingStates = new Map<string, any>();
    const weighStates = new Map<string, any>();

    // Preload states
    if (reports && reports.length){
      const poiIds = Array.from(new Set((reports as any[]).map(r=>r.poi_id)));
      const [{ data: ps }, { data: ws }] = await Promise.all([
        admin.from('parking_state').select('poi_id, occupancy, confidence').in('poi_id', poiIds),
        admin.from('weigh_station_state').select('poi_id, status, confidence').in('poi_id', poiIds),
      ]);
      for (const r of (ps ?? []) as any[]) parkingStates.set(r.poi_id, r);
      for (const r of (ws ?? []) as any[]) weighStates.set(r.poi_id, r);
    }

    // Aggregate per user agreement score
    const agg = new Map<string, { agree: number; total: number; base: number }>();
    for (const r of (reports ?? []) as any[]){
      const key = r.user_id as string;
      const a = agg.get(key) ?? { agree: 0, total: 0, base: 0.5 };
      let agrees = false;
      if (r.kind === 'parking') {
        const st = parkingStates.get(r.poi_id);
        if (st && typeof st.occupancy === 'string') {
          const s = String(r.status || '').toLowerCase();
          if (s && s === st.occupancy) agrees = true;
        }
      } else if (r.kind === 'weigh') {
        const st = weighStates.get(r.poi_id);
        if (st && typeof st.status === 'string') {
          const s = String(r.status || '').toLowerCase();
          if (s && s === st.status) agrees = true;
        }
      }
      a.total += 1;
      if (agrees) a.agree += 1;
      agg.set(key, a);
    }

    // Write back trust scores
    for (const [user_id, a] of agg.entries()){
      const accuracy = a.total > 0 ? a.agree / a.total : 0.5;
      // features: account age and verification could be pulled; here we store accuracy only
      let score = 0.3 + 0.7 * accuracy; // clamp later
      score = Math.max(0.1, Math.min(0.99, score));
      const features = { accuracy_24h: Number(accuracy.toFixed(3)) };
      await admin.from('user_trust').upsert({ user_id, score: Number(score.toFixed(3)), last_calc: new Date().toISOString(), features }, { onConflict: 'user_id' });
    }

    return new Response(JSON.stringify({ ok: true, updated: agg.size }), { headers: { 'content-type': 'application/json' } });
  } catch (e) {
    return new Response(JSON.stringify({ error: String(e) }), { status: 500, headers: { 'content-type': 'application/json' } });
  }
});
