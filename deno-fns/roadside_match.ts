// deno-fns/roadside_match.ts
// Endpoint: POST /roadside/match
// Input: { lat: number; lng: number; service_type: string; limit?: number }
// Ranks providers by proximity and simple placeholder scores (capacity/SLA/rating).
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const SERVICE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE")!;
const db = createClient(SUPABASE_URL, SERVICE_KEY, { auth: { persistSession: false }});

type Input = { lat: number; lng: number; service_type: string; limit?: number };

type Loc = { lat: number; lng: number };
function haversineKm(a: Loc, b: Loc) {
  const R = 6371;
  const dLat = (b.lat - a.lat) * Math.PI / 180;
  const dLng = (b.lng - a.lng) * Math.PI / 180;
  const la1 = a.lat * Math.PI / 180, la2 = b.lat * Math.PI / 180;
  const h = Math.sin(dLat/2)**2 + Math.cos(la1)*Math.cos(la2)*Math.sin(dLng/2)**2;
  return 2*R*Math.asin(Math.sqrt(h));
}

Deno.serve(async (req) => {
  try {
    if (req.method !== "POST") return new Response("Method Not Allowed", { status: 405 });
    const body = await req.json().catch(() => ({} as any)) as Input;
    const lat = Number(body.lat), lng = Number(body.lng);
    const service_type = String(body.service_type || '').trim();
    const limit = Number.isFinite(body.limit) ? Math.max(1, Number(body.limit)) : 5;
    if (!Number.isFinite(lat) || !Number.isFinite(lng) || !service_type) {
      return new Response(JSON.stringify({ error: 'bad_request' }), { status: 400, headers: { 'content-type': 'application/json' } });
    }

    // 1) Active providers
    // Using generic selects to avoid hard dependencies if some tables are missing in a given deployment.
    const { data: providers } = await db.from('roadside_providers').select('id, org_id, name, status').eq('status','active');
    const { data: services } = await db.from('roadside_services').select('provider_id, service_types, eta_minutes');
    const { data: locs } = await db.from('roadside_locations').select('provider_id, lat, lng, coverage_radius_km');

    const svcByProv = new Map<string, any>();
    for (const s of (services || []) as any[]) svcByProv.set(String(s.provider_id), s);
    const locByProv = new Map<string, any>();
    for (const l of (locs || []) as any[]) if (!locByProv.has(String(l.provider_id))) locByProv.set(String(l.provider_id), l);

    const here = { lat, lng };
    const candidates: any[] = [];

    for (const p of (providers || []) as any[]) {
      const pid = String(p.id);
      const svc = svcByProv.get(pid);
      const loc = locByProv.get(pid);
      if (!svc || !loc) continue;
      const types: string[] = Array.isArray(svc.service_types) ? svc.service_types.map((x: any) => String(x)) : [];
      if (!types.includes(service_type)) continue;

      const distKm = haversineKm(here, { lat: Number(loc.lat), lng: Number(loc.lng) });
      const radius = Number(loc.coverage_radius_km || 0);
      if (radius > 0 && distKm > radius) continue;

      // Placeholder scores (could be replaced by live KPIs/capacity and SLA metrics)
      const capacityScore = 0.8;
      const slaScore = 0.9;
      const ratingScore = 0.85;
      const distScore = 1 / (1 + distKm / 10);
      const score = 0.4*distScore + 0.2*capacityScore + 0.2*slaScore + 0.2*ratingScore;

      candidates.push({
        provider_id: pid,
        name: String(p.name || ''),
        dist_km: Math.round(distKm*10)/10,
        est_eta_min: Number(svc.eta_minutes || 30),
        score,
      });
    }

    candidates.sort((a,b) => b.score - a.score);
    return new Response(JSON.stringify({ candidates: candidates.slice(0, limit) }), { headers: { 'content-type': 'application/json' } });
  } catch (e) {
    return new Response(String((e as any)?.message || e), { status: 400 });
  }
});
