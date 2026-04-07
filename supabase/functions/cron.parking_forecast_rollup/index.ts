// Supabase Edge Function (scheduled): cron.parking_forecast_rollup
// Seeds/updates parking_forecast with simple DoW/hour rolling averages from recent parking reports.
// Runs nightly or hourly. Safe to run repeatedly (upserts by poi_id,dow,hour).

import "jsr:@supabase/functions-js/edge-runtime";
import { createClient } from "npm:@supabase/supabase-js@2";

const URL = Deno.env.get("SUPABASE_URL")!;
const SERVICE = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;

Deno.serve(async (_req) => {
  try {
    const admin = createClient(URL, SERVICE);
    const now = new Date();
    const lookbackDays = Number(Deno.env.get('FORECAST_LOOKBACK_DAYS') ?? 28);
    const sinceIso = new Date(Date.now() - Math.max(7, Math.min(90, lookbackDays)) * 24 * 60 * 60 * 1000).toISOString();

    // Pull recent parking reports (kind='parking')
    const { data: rows, error } = await admin
      .from('poi_reports')
      .select('poi_id, status, ts')
      .eq('kind', 'parking')
      .gte('ts', sinceIso);
    if (error) return new Response(JSON.stringify({ error: error.message }), { status: 500, headers: { 'content-type':'application/json' } });

    // Bucket by poi_id, dow (0=Sun), hour (0-23)
    type Counts = { open: number; some: number; full: number; total: number };
    const buckets = new Map<string, Counts>();

    for (const r of (rows ?? []) as any[]){
      const ts = new Date(r.ts);
      const dow = ts.getUTCDay();
      const hour = ts.getUTCHours();
      const key = `${r.poi_id}|${dow}|${hour}`;
      const c = buckets.get(key) ?? { open: 0, some: 0, full: 0, total: 0 };
      const s = String(r.status || '').toLowerCase();
      if (s === 'open') c.open += 1;
      else if (s === 'some') c.some += 1;
      else if (s === 'full') c.full += 1;
      c.total += 1;
      buckets.set(key, c);
    }

    // Prepare upserts with Laplace smoothing
    const upserts: any[] = [];
    for (const [key, c] of buckets.entries()){
      const [poi_id, sdow, shour] = key.split('|');
      const dow = Number(sdow);
      const hour = Number(shour);
      const denom = c.total + 3; // +1 for each category
      const p_open = (c.open + 1) / denom;
      const p_some = (c.some + 1) / denom;
      const p_full = (c.full + 1) / denom;
      upserts.push({ poi_id, dow, hour, p_open, p_some, p_full, eta_80pct: null, updated_at: now.toISOString() });
    }

    // Write in chunks to avoid payload limits
    const chunkSize = 800;
    for (let i=0;i<upserts.length;i+=chunkSize){
      const chunk = upserts.slice(i, i+chunkSize);
      const { error: uerr } = await admin.from('parking_forecast').upsert(chunk, { onConflict: 'poi_id,dow,hour' });
      if (uerr) return new Response(JSON.stringify({ error: uerr.message, wrote: i }), { status: 500, headers: { 'content-type':'application/json' } });
    }

    return new Response(JSON.stringify({ ok: true, updated: upserts.length }), { headers: { 'content-type': 'application/json' } });
  } catch (e) {
    return new Response(JSON.stringify({ error: String(e) }), { status: 500, headers: { 'content-type':'application/json' } });
  }
});
