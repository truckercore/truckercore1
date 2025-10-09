// Supabase Edge Function: parking.forecast.seed
// One-time/backfill helper to ensure parking_forecast has rows for POIs.
// Behavior:
// - For POIs (truck_stop/parking) with no parking_forecast rows, seed 168 (7x24) rows with uniform 1/3 probabilities.
// - Safe to run multiple times; skips POIs that already have any rows.
// - Chunks writes to avoid payload limits.
// GET /functions/v1/parking.forecast.seed?limit=<n>&kinds=truck_stop,parking

import "jsr:@supabase/functions-js/edge-runtime";
import { createClient } from "npm:@supabase/supabase-js@2";

const URL = Deno.env.get("SUPABASE_URL")!;
const SERVICE = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;

function bad(status: number, msg: string){
  return new Response(JSON.stringify({ error: msg }), { status, headers: { "content-type":"application/json" } });
}

Deno.serve(async (req) => {
  const started = Date.now();
  try {
    if (req.method !== 'GET') return bad(405, 'method_not_allowed');

    const qs = new URL(req.url).searchParams;
    const limit = Math.max(1, Math.min(10000, Number(qs.get('limit') ?? 5000)));
    const kinds = (qs.get('kinds') ?? 'truck_stop,parking').split(',').map(s=>s.trim()).filter(Boolean);

    const admin = createClient(URL, SERVICE);

    // Determine source table: points_of_interest or pois
    let pois: Array<{ id: string }>|null = null;
    try {
      const { data } = await admin
        .from('points_of_interest')
        .select('id, poi_type')
        .in('poi_type', kinds)
        .limit(limit);
      if (Array.isArray(data)) pois = (data as any[]).map(r=>({ id: r.id as string }));
    } catch {}

    if (!pois) {
      const { data } = await admin
        .from('pois')
        .select('id, kind')
        .in('kind', kinds)
        .limit(limit);
      pois = (data ?? []).map((r:any)=>({ id: r.id as string }));
    }

    if (!pois || pois.length === 0){
      return new Response(JSON.stringify({ ok: true, seeded_pois: 0, wrote_rows: 0, duration_ms: Date.now()-started }), { headers: { 'content-type':'application/json' } });
    }

    // Filter to POIs without any forecast
    const ids = pois.map(p=>p.id);
    const { data: existing } = await admin
      .from('parking_forecast')
      .select('poi_id')
      .in('poi_id', ids);
    const hasSet = new Set((existing ?? []).map((r:any)=>r.poi_id as string));
    const targets = ids.filter(id=>!hasSet.has(id));

    if (targets.length === 0){
      return new Response(JSON.stringify({ ok: true, seeded_pois: 0, wrote_rows: 0, duration_ms: Date.now()-started }), { headers: { 'content-type':'application/json' } });
    }

    // Build uniform rows for all dow/hour
    const nowIso = new Date().toISOString();
    const rows: any[] = [];
    for (const poi_id of targets){
      for (let dow=0; dow<7; dow++){
        for (let hour=0; hour<24; hour++){
          rows.push({ poi_id, dow, hour, p_open: 1/3, p_some: 1/3, p_full: 1/3, eta_80pct: null, updated_at: nowIso });
        }
      }
    }

    // Upsert in chunks
    let wrote = 0;
    const chunk = 800;
    for (let i=0; i<rows.length; i+=chunk){
      const part = rows.slice(i, i+chunk);
      const { error } = await admin.from('parking_forecast').upsert(part, { onConflict: 'poi_id,dow,hour' });
      if (error) return bad(500, error.message);
      wrote += part.length;
    }

    const res = { ok: true, seeded_pois: targets.length, wrote_rows: wrote, duration_ms: Date.now()-started };
    try { console.log(JSON.stringify({ event: 'seed.parking_forecast', pois: targets.length, wrote_rows: wrote, duration_ms: res.duration_ms })); } catch {}
    return new Response(JSON.stringify(res), { headers: { 'content-type':'application/json' } });
  } catch (e) {
    return bad(500, String(e));
  }
});
