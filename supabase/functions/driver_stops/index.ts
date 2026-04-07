// Supabase Edge Function: driver_stops
// Path: supabase/functions/driver_stops/index.ts
// Invoke: GET /functions/v1/driver_stops?lat=..&lng=..&radius_km=..&filters=..
// Returns: ranked stops with { location_id, name, lat, lng, score, badges[], factors, confidence }

import "jsr:@supabase/functions-js/edge-runtime";
import { serve } from "https://deno.land/std@0.224.0/http/server.ts";
import { createClient } from "npm:@supabase/supabase-js@2";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const SUPABASE_ANON = Deno.env.get("SUPABASE_ANON") ?? Deno.env.get("SUPABASE_ANON_KEY");
if (!SUPABASE_ANON) {
  throw new Error("Missing SUPABASE_ANON (fallback SUPABASE_ANON_KEY not set)");
}
if (!Deno.env.get("SUPABASE_ANON") && Deno.env.get("SUPABASE_ANON_KEY")) {
  console.warn("[deprecation] SUPABASE_ANON_KEY is deprecated in Edge Functions; please set SUPABASE_ANON instead");
}

function toNumber(q: URLSearchParams, k: string, def: number): number {
  const v = q.get(k);
  const n = v != null ? Number(v) : NaN;
  return Number.isFinite(n) ? n : def;
}

function kmToDegLat(km: number) { return km / 110.574; }
function kmToDegLng(km: number, lat: number) { return km / (111.320 * Math.cos(lat * Math.PI / 180)); }

serve(async (req) => {
  try {
    const url = new URL(req.url);
    const qs = url.searchParams;
    const lat = toNumber(qs, "lat", NaN);
    const lng = toNumber(qs, "lng", NaN);
    const radiusKm = Math.max(1, toNumber(qs, "radius_km", 50));

    const auth = req.headers.get("Authorization") ?? "";
    const user = createClient(SUPABASE_URL, SUPABASE_ANON, { global: { headers: { Authorization: auth } } });

    // Optional: get user preferences for personalization
    let user_id: string | null = null;
    try {
      const { data } = await user.auth.getUser();
      user_id = data?.user?.id ?? null;
    } catch { /* anonymous allowed */ }

    let prefs: any = null;
    if (user_id) {
      const { data: p } = await user.from("user_preferences").select("loyalty_brands, amenity_priority, detour_tolerance").eq("user_id", user_id).maybeSingle();
      prefs = p ?? null;
    }

    // Spatial filter (simple bbox for portability). If lat/lng missing, return top N by score.
    let locationsQuery = user.from("locations").select("location_id,name,lat,lng,org_id");
    if (Number.isFinite(lat) && Number.isFinite(lng)) {
      const dLat = kmToDegLat(radiusKm);
      const dLng = kmToDegLng(radiusKm, lat);
      locationsQuery = locationsQuery
        .gte("lat", lat - dLat).lte("lat", lat + dLat)
        .gte("lng", lng - dLng).lte("lng", lng + dLng);
    }

    const { data: locs, error: lerr } = await locationsQuery.limit(500);
    if (lerr) throw lerr;

    const ids = (locs ?? []).map((l: any) => l.location_id);
    if (!ids.length) return new Response(JSON.stringify({ stops: [] }), { headers: { "content-type": "application/json" } });

    // Fetch scores and confidence in bulk
    const [{ data: scores }, { data: confs }] = await Promise.all([
      user.from("stop_scores").select("location_id,score,factors").in("location_id", ids),
      user.from("stop_confidence").select("location_id,confidence,last_update").in("location_id", ids),
    ]);

    const mapScore = new Map<string, any>();
    for (const s of (scores ?? []) as any[]) mapScore.set(s.location_id, s);
    const mapConf = new Map<string, any>();
    for (const c of (confs ?? []) as any[]) mapConf.set(c.location_id, c);

    // Fuel price badge: read latest effective price for visible locations
    const { data: fuels } = await user
      .from("fuel_prices")
      .select("location_id,diesel_cents,discount_cents,effective_at")
      .in("location_id", ids)
      .order("effective_at", { ascending: false })
      .limit(1, { foreignTable: undefined });

    const latestFuel = new Map<string, { price: number }>();
    for (const f of (fuels ?? []) as any[]) {
      const price = (f.diesel_cents ?? 0) - (f.discount_cents ?? 0);
      if (!latestFuel.has(f.location_id)) latestFuel.set(f.location_id, { price });
    }

    // Find cheapest to award badge
    let minPrice = Infinity;
    for (const v of latestFuel.values()) minPrice = Math.min(minPrice, v.price);

    // Build results
    const items = (locs ?? []).map((l: any) => {
      const sc = mapScore.get(l.location_id);
      const cf = mapConf.get(l.location_id);
      const price = latestFuel.get(l.location_id)?.price ?? null;
      const badges: string[] = [];
      if (cf && (cf.confidence ?? 0) > 0.7) badges.push("Most parking now");
      if (price != null && price === minPrice && isFinite(minPrice)) badges.push("Cheapest diesel");
      // Simple personalization badge
      if (prefs?.loyalty_brands && Array.isArray(prefs.loyalty_brands) && prefs.loyalty_brands.length) {
        // demo: if org name contains loyalty brand (requires join); skip heavy join, fallback to generic badge
        badges.push("Best for you");
      }
      return {
        location_id: l.location_id,
        name: l.name,
        lat: l.lat,
        lng: l.lng,
        score: sc?.score ?? 0,
        factors: sc?.factors ?? { parking: 0, fuel: 0, amenities: 0, detour: 0, loyalty_boost: 0 },
        confidence: cf?.confidence ?? 0,
        badges,
      };
    });

    items.sort((a: any, b: any) => (b.score ?? 0) - (a.score ?? 0));

    return new Response(JSON.stringify({ stops: items }), { headers: { "content-type": "application/json" } });
  } catch (e) {
    return new Response(JSON.stringify({ error: String(e) }), { status: 500, headers: { "content-type": "application/json" } });
  }
});
