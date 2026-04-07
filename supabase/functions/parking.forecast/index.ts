// Supabase Edge Function: parking.forecast
// GET /functions/v1/parking.forecast?poi_id=uuid
// Returns DoW/hour probabilities for parking occupancy for the given POI.

import "jsr:@supabase/functions-js/edge-runtime";
import { createClient } from "npm:@supabase/supabase-js@2";

const URL = Deno.env.get("SUPABASE_URL")!;
const ANON = Deno.env.get("SUPABASE_ANON") ?? Deno.env.get("SUPABASE_ANON_KEY");
if (!ANON) throw new Error("Missing SUPABASE_ANON (fallback SUPABASE_ANON_KEY not set)");
const SERVICE = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;

function bad(status: number, msg: string){
  return new Response(JSON.stringify({ error: msg }), { status, headers: { "content-type":"application/json", "access-control-allow-origin": "*" } });
}

Deno.serve(async (req) => {
  const started = Date.now();
  try {
    if (req.method === 'OPTIONS'){
      return new Response(null, { headers: { "access-control-allow-origin": "*", "access-control-allow-headers": "authorization, content-type", "access-control-allow-methods": "GET, OPTIONS" } });
    }
    if (req.method !== 'GET') return bad(405, 'method_not_allowed');

    const qs = new URL(req.url).searchParams;
    const poi_id = String(qs.get('poi_id') || '').trim();
    if (!poi_id) return bad(400, 'missing_poi_id');

    const admin = createClient(URL, SERVICE);

    const { data, error } = await admin
      .from('parking_forecast')
      .select('dow,hour,p_open,p_some,p_full,eta_80pct,updated_at')
      .eq('poi_id', poi_id)
      .order('dow', { ascending: true })
      .order('hour', { ascending: true });
    if (error) return bad(500, error.message);

    const items = (data ?? []).map((r: any) => ({
      dow: r.dow,
      hour: r.hour,
      p_open: Number(r.p_open ?? 0),
      p_some: Number(r.p_some ?? 0),
      p_full: Number(r.p_full ?? 0),
      eta_80pct: r.eta_80pct,
      updated_at: r.updated_at
    }));

    // Simple ETag: count + last updated
    const last = items.length ? items[items.length - 1].updated_at : '';
    const etag = `W/"pf-${items.length}-${last}"`;
    const inm = req.headers.get('If-None-Match');
    if (inm && inm === etag) return new Response(null, { status: 304, headers: { "access-control-allow-origin": "*", "ETag": etag, "Cache-Control": "public, max-age=300, stale-while-revalidate=300" } });

    const now = Date.now();
    const latest = items.length ? (new Date(items[items.length - 1].updated_at)).getTime() : 0;
    const max_age_min = latest ? Math.round((now - latest) / 60000) : null;
    const duration_ms = Date.now() - started;
    try { console.log(JSON.stringify({ event: 'endpoint', name: 'parking.forecast', items: items.length, max_age_min, duration_ms })); } catch {}

    return new Response(JSON.stringify({ ok: true, poi_id, items }), {
      headers: {
        "content-type": "application/json",
        "access-control-allow-origin": "*",
        "Cache-Control": "public, max-age=300, stale-while-revalidate=300",
        "ETag": etag
      }
    });
  } catch (e) {
    return bad(500, String(e));
  }
});
