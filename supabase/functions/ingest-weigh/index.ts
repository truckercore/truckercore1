// supabase/functions/ingest-weigh/index.ts
// Ingest DOT weigh station static metadata and latest status into Supabase tables.
// Env:
//  - SUPABASE_URL
//  - SUPABASE_SERVICE_ROLE (or SUPABASE_SERVICE_ROLE_KEY)
//  - DOT_STATIONS_URL (JSON feed)
//  - SCALE_STATUS_URL (JSON feed)

import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const url = Deno.env.get("SUPABASE_URL")!;
const svc = Deno.env.get("SUPABASE_SERVICE_ROLE") || Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
if (!url || !svc) {
  console.warn("[ingest-weigh] Missing SUPABASE_URL or service role key env");
}
const adminClient = createClient(url ?? "", svc ?? "", { auth: { persistSession: false } });

const DOT_STATIONS_URL = Deno.env.get('DOT_STATIONS_URL') || '';
const STATUS_URL = Deno.env.get('SCALE_STATUS_URL') || '';

function corsHeaders(origin?: string | null) {
  return { "Access-Control-Allow-Origin": origin || "*", "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type" } as Record<string,string>;
}

async function upsertStations() {
  if (!DOT_STATIONS_URL) return { inserted: 0 };
  const res = await fetch(DOT_STATIONS_URL);
  if (!res.ok) return { inserted: 0 };
  const data = await res.json();
  let inserted = 0;
  for (const r of (data ?? [])) {
    const { error } = await adminClient.from('weigh_stations').upsert({
      ext_id: r.ext_id ?? r.id ?? null,
      name: r.name,
      state: r.state,
      location: `SRID=4326;POINT(${r.lon} ${r.lat})`,
      direction: r.direction ?? null,
      facilities: r.facilities ?? {}
    }, { onConflict: 'ext_id' });
    if (!error) inserted++;
  }
  return { inserted };
}

async function upsertStatus() {
  if (!STATUS_URL) return { rows: 0 };
  const res = await fetch(STATUS_URL);
  if (!res.ok) return { rows: 0 };
  const data = await res.json();
  let rows = 0;
  for (const s of (data ?? [])) {
    const station = await adminClient.from('weigh_stations').select('id').eq('ext_id', s.ext_id ?? s.id).maybeSingle();
    const id = (station.data as any)?.id as string | undefined;
    if (!id) continue;
    const { error } = await adminClient.from('weigh_station_status').upsert({
      station_id: id,
      status: s.status ?? 'unknown',
      source: s.source ?? 'dot',
      observed_at: s.observed_at ?? new Date().toISOString(),
      meta: s.meta ?? {}
    });
    if (!error) rows++;
  }
  return { rows };
}

export default Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: corsHeaders(req.headers.get('origin')) });
  try {
    const a = await upsertStations();
    const b = await upsertStatus();
    return new Response(JSON.stringify({ ok: true, stations_upserted: a.inserted, statuses: b.rows }), {
      headers: { 'Content-Type': 'application/json', ...corsHeaders(req.headers.get('origin')) }
    });
  } catch (e) {
    return new Response(JSON.stringify({ ok: false, error: String(e) }), { status: 500, headers: { 'Content-Type': 'application/json', ...corsHeaders(req.headers.get('origin')) } });
  }
});
