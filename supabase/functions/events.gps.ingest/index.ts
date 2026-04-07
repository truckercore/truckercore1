// Supabase Edge Function: events.gps.ingest
// POST /functions/v1/events.gps.ingest
// Body: { org_id?, coarse?, samples: [{ lat,lng,speed_kph?,heading_deg?,accuracy_m?,source?,ts? }, ...] }
// Inserts GPS samples for the authenticated user with optional coarse rounding.

import "jsr:@supabase/functions-js/edge-runtime";
import { createClient } from "npm:@supabase/supabase-js@2";

const URL = Deno.env.get("SUPABASE_URL")!;
const ANON = Deno.env.get("SUPABASE_ANON") ?? Deno.env.get("SUPABASE_ANON_KEY");
if (!ANON) throw new Error("Missing SUPABASE_ANON (fallback SUPABASE_ANON_KEY not set)");

function bad(status: number, message: string){
  return new Response(JSON.stringify({ error: message }), { status, headers: { "content-type": "application/json" } });
}

function roundCoord(x: number, granularityMeters = 75){
  // Approximate meters per degree latitude ~111,320m; longitude scaled by cos(lat).
  const deg = granularityMeters / 111_320;
  return Math.round(x / deg) * deg;
}

function validLatLng(lat: number, lng: number){
  return Number.isFinite(lat) && Number.isFinite(lng) && lat <= 90 && lat >= -90 && lng <= 180 && lng >= -180;
}

Deno.serve(async (req) => {
  try {
    if (req.method !== 'POST') return bad(405, 'method_not_allowed');
    const auth = req.headers.get('Authorization') ?? '';
    const supa = createClient(URL, ANON, { global: { headers: { Authorization: auth } } });

    const { data: ures } = await supa.auth.getUser();
    if (!ures?.user) return bad(401, 'auth_required');

    const body = await req.json().catch(()=>({} as any));
    const org_id = body.org_id ? String(body.org_id) : null;
    const coarse = Boolean(body.coarse);
    const samples = Array.isArray(body.samples) ? body.samples : [];
    if (!samples.length) return bad(400, 'no_samples');

    // Rate limit basic: max 200 inserts per 5 minutes per user (server-side aggregate check)
    const fiveMinAgo = new Date(Date.now() - 5 * 60_000).toISOString();
    const { data: recent } = await supa.from('gps_samples').select('id', { count: 'exact', head: true })
      .gte('ts', fiveMinAgo)
      .eq('user_id', ures.user.id);
    const recentCount = (recent as any)?.length ?? 0; // fallback
    if (recentCount > 200) return bad(429, 'rate_limited');

    const rows: any[] = [];
    for (const s of samples){
      const lat = Number(s?.lat);
      const lng = Number(s?.lng);
      if (!validLatLng(lat, lng)) continue;
      const acc = s?.accuracy_m != null ? Number(s.accuracy_m) : null;
      const speed = s?.speed_kph != null ? Number(s.speed_kph) : null;
      const heading = s?.heading_deg != null ? Number(s.heading_deg) : null;
      const src = (s?.source === 'sdk' ? 'sdk' : 'mobile');
      let plat = lat, plng = lng;
      if (coarse) {
        plat = roundCoord(lat, 75);
        // longitude rounding should account for latitude scale; simple approach: scale granularity
        const scale = Math.cos((lat * Math.PI) / 180) || 1;
        const lonGranM = 75;
        const lonDeg = (lonGranM / 111_320) / Math.max(0.2, Math.abs(scale));
        plng = Math.round(lng / lonDeg) * lonDeg;
      }
      const ts = s?.ts ? new Date(s.ts).toISOString() : new Date().toISOString();
      rows.push({ user_id: ures.user.id, org_id, lat: plat, lng: plng, speed_kph: speed, heading_deg: heading, accuracy_m: acc, source: src, ts });
      if (rows.length >= 50) break; // guard against huge payloads
    }

    if (!rows.length) return bad(400, 'no_valid_samples');

    const { error } = await supa.from('gps_samples').insert(rows);
    if (error) return bad(500, error.message);

    return new Response(JSON.stringify({ ok: true, accepted: rows.length, skipped: samples.length - rows.length }), { headers: { 'content-type': 'application/json' } });
  } catch (e) {
    return bad(500, String(e));
  }
});
