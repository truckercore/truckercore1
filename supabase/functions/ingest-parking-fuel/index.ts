// supabase/functions/ingest-parking-fuel/index.ts
// Ingest parking occupancy and fuel prices feeds. Also upserts basic truck stop metadata.
// Env:
//  - SUPABASE_URL
//  - SUPABASE_SERVICE_ROLE (or SUPABASE_SERVICE_ROLE_KEY)
//  - PARKING_URL (JSON)
//  - FUEL_URL (JSON)

import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const url = Deno.env.get("SUPABASE_URL")!;
const svc = Deno.env.get("SUPABASE_SERVICE_ROLE") || Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
if (!url || !svc) {
  console.warn("[ingest-parking-fuel] Missing SUPABASE_URL or service role key env");
}
const adminClient = createClient(url ?? "", svc ?? "", { auth: { persistSession: false } });

const PARKING_URL = Deno.env.get('PARKING_URL') || '';
const FUEL_URL = Deno.env.get('FUEL_URL') || '';

function corsHeaders(origin?: string | null) {
  return { "Access-Control-Allow-Origin": origin || "*", "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type" } as Record<string,string>;
}

async function upsertStopsFromFeed(stops: any[]) {
  for (const s of stops) {
    await adminClient.from('truck_stops').upsert({
      ext_id: s.ext_id ?? s.id ?? null,
      name: s.name,
      brand: s.brand ?? null,
      location: `SRID=4326;POINT(${s.lon} ${s.lat})`,
      amenities: s.amenities ?? {}
    }, { onConflict: 'ext_id' });
  }
}

export default Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: corsHeaders(req.headers.get('origin')) });
  const out: any = { ok: true };

  try {
    if (PARKING_URL) {
      const res = await fetch(PARKING_URL);
      if (res.ok) {
        const data = await res.json();
        await upsertStopsFromFeed(data.stops ?? []);
        let rows = 0;
        for (const r of (data.readings ?? [])) {
          const stop = await adminClient.from('truck_stops').select('id').eq('ext_id', r.ext_id ?? r.id).maybeSingle();
          const sid = (stop.data as any)?.id as string | undefined;
          if (!sid) continue;
          const { error } = await adminClient.from('parking_status').upsert({
            stop_id: sid,
            occupancy_pct: r.occupancy_pct,
            spots_total: r.spots_total ?? null,
            source: r.source ?? 'partner',
            observed_at: r.observed_at ?? new Date().toISOString(),
            meta: r.meta ?? {}
          });
          if (!error) rows++;
        }
        out.parking_rows = rows;
      }
    }

    if (FUEL_URL) {
      const res = await fetch(FUEL_URL);
      if (res.ok) {
        const data = await res.json();
        let rows = 0;
        for (const r of (data.prices ?? [])) {
          const stop = await adminClient.from('truck_stops').select('id').eq('ext_id', r.ext_id ?? r.id).maybeSingle();
          const sid = (stop.data as any)?.id as string | undefined;
          if (!sid) continue;
          const { error } = await adminClient.from('fuel_prices').upsert({
            stop_id: sid,
            diesel_price_usd: r.diesel_price_usd,
            discount_usd: r.discount_usd ?? null,
            source: r.source ?? 'partner',
            observed_at: r.observed_at ?? new Date().toISOString(),
            meta: r.meta ?? {}
          });
          if (!error) rows++;
        }
        out.fuel_rows = rows;
      }
    }

    return new Response(JSON.stringify(out), { headers: { 'Content-Type': 'application/json', ...corsHeaders(req.headers.get('origin')) } });
  } catch (e) {
    return new Response(JSON.stringify({ ok: false, error: String(e) }), { status: 500, headers: { 'Content-Type': 'application/json', ...corsHeaders(req.headers.get('origin')) } });
  }
});
