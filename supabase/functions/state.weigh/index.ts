// Supabase Edge Function: state.weigh
// GET /functions/v1/state.weigh?bbox=west,south,east,north&min_conf=0.4
// Returns weigh station status for POIs within bbox with optional confidence threshold.

import "jsr:@supabase/functions-js/edge-runtime";
import { createClient } from "npm:@supabase/supabase-js@2";

const URL = Deno.env.get("SUPABASE_URL")!;
const ANON = Deno.env.get("SUPABASE_ANON") ?? Deno.env.get("SUPABASE_ANON_KEY");
if (!ANON) throw new Error("Missing SUPABASE_ANON (fallback SUPABASE_ANON_KEY not set)");
const SERVICE = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;

function bad(status: number, msg: string){
  return new Response(JSON.stringify({ error: msg }), { status, headers: { "content-type": "application/json", "access-control-allow-origin": "*" } });
}

function parseBbox(raw: string | null){
  if (!raw) return null;
  const parts = raw.split(",").map((s)=>Number(s.trim()));
  if (parts.length !== 4 || parts.some((x)=>!Number.isFinite(x))) return null;
  const [west, south, east, north] = parts;
  if (west < -180 || east > 180 || south < -90 || north > 90) return null;
  return { west, south, east, north };
}

Deno.serve(async (req) => {
  const started = Date.now();
  try {
    if (req.method === "OPTIONS") {
      return new Response(null, { headers: { "access-control-allow-origin": "*", "access-control-allow-headers": "authorization, content-type", "access-control-allow-methods": "GET, OPTIONS" } });
    }
    if (req.method !== "GET") return bad(405, "method_not_allowed");

    const qs = new URL(req.url).searchParams;
    const bbox = parseBbox(qs.get("bbox"));
    const min_conf = Math.max(0, Math.min(1, Number(qs.get("min_conf") ?? 0)));
    if (!bbox) return bad(400, "invalid_bbox");

    const admin = createClient(URL, SERVICE);

    // Try points_of_interest first (poi_type weigh_station)
    let pois: Array<{ id: string; name: string | null; lat: number; lng: number }>|null = null;
    try {
      const { data } = await admin
        .from("points_of_interest")
        .select("id,name,geo_lat,geo_lng,poi_type")
        .gte("geo_lat", bbox.south)
        .lte("geo_lat", bbox.north)
        .gte("geo_lng", bbox.west)
        .lte("geo_lng", bbox.east)
        .eq("poi_type", "weigh_station");
      if (Array.isArray(data)) {
        pois = data.map((r:any)=>({ id: r.id, name: r.name ?? null, lat: Number(r.geo_lat), lng: Number(r.geo_lng) }));
      }
    } catch {}

    if (!pois) {
      try {
        const { data } = await admin
          .from("pois")
          .select("id,name,lat,lng,kind")
          .gte("lat", bbox.south)
          .lte("lat", bbox.north)
          .gte("lng", bbox.west)
          .lte("lng", bbox.east)
          .eq("kind", "weigh_station");
        if (Array.isArray(data)) {
          pois = data.map((r:any)=>({ id: r.id, name: r.name ?? null, lat: Number(r.lat), lng: Number(r.lng) }));
        }
      } catch {}
    }

    if (!pois || pois.length === 0) {
      return new Response(JSON.stringify({ ok: true, items: [] }), { headers: { "content-type": "application/json", "access-control-allow-origin": "*" } });
    }

    const poiIds = pois.map(p=>p.id);
    const { data: states } = await admin
      .from("weigh_station_state")
      .select("poi_id, status, confidence, last_update, source_mix")
      .in("poi_id", poiIds);

    const mapState = new Map<string, any>();
    for (const s of (states ?? []) as any[]) mapState.set(s.poi_id, s);

    let items = pois
      .map((p)=>{
        const st = mapState.get(p.id);
        if (!st) return null;
        if (typeof st.confidence === "number" && st.confidence < min_conf) return null;
        return {
          poi_id: p.id,
          name: p.name,
          lat: p.lat,
          lng: p.lng,
          status: st.status,
          confidence: st.confidence ?? 0,
          last_update: st.last_update,
          source_mix: st.source_mix ?? {},
        } as any;
      })
      .filter(Boolean) as any[];

    // Pagination
    const page = Math.max(1, Number(qs.get("page") ?? 1));
    const pageSizeRaw = Number(qs.get("page_size") ?? 200);
    const page_size = Math.max(1, Math.min(500, Number.isFinite(pageSizeRaw) ? pageSizeRaw : 200));
    const start = (page - 1) * page_size;
    const end = start + page_size;
    const has_more = items.length > end;
    const paged = items.slice(start, end);

    // ETag based on count and max last_update within page
    const maxTs = paged.reduce<string>((acc, it) => (!acc || (it.last_update && it.last_update > acc) ? it.last_update : acc), "");
    const etag = `W/"ws-${paged.length}-${maxTs}"`;
    const inm = req.headers.get("If-None-Match");
    if (inm && inm === etag) {
      return new Response(null, { status: 304, headers: { "access-control-allow-origin": "*", "ETag": etag, "Cache-Control": "public, max-age=15, stale-while-revalidate=30" } });
    }

    const duration_ms = Date.now() - started;
    try { console.log(JSON.stringify({ event: 'endpoint', name: 'state.weigh', items: paged.length, page, page_size, has_more, duration_ms })); } catch {}
    return new Response(JSON.stringify({ ok: true, items: paged, page, page_size, has_more }), { headers: { "content-type": "application/json", "access-control-allow-origin": "*", "Cache-Control": "public, max-age=15, stale-while-revalidate=30", "ETag": etag } });
  } catch (e) {
    return bad(500, String(e));
  }
});
