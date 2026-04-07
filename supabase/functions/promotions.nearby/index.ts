// Supabase Edge Function: promotions.nearby (driver)
// GET /functions/v1/promotions.nearby?lat=..&lng=..&radius_km=25
// Returns active promos within radius, ranked by relevance with score + factors.

import "jsr:@supabase/functions-js/edge-runtime";
import { createClient } from "npm:@supabase/supabase-js@2";

const URL = Deno.env.get("SUPABASE_URL")!;
const ANON = Deno.env.get("SUPABASE_ANON") ?? Deno.env.get("SUPABASE_ANON_KEY");
if (!ANON) throw new Error("Missing SUPABASE_ANON (fallback SUPABASE_ANON_KEY not set)");
if (!Deno.env.get("SUPABASE_ANON") && Deno.env.get("SUPABASE_ANON_KEY")) {
  console.warn("[deprecation] SUPABASE_ANON_KEY is deprecated in Edge Functions; please set SUPABASE_ANON instead");
}

function haversineKm(a: {lat:number; lng:number}, b:{lat:number; lng:number}){
  const toRad = (x:number)=>x*Math.PI/180;
  const R=6371; const dLat=toRad(b.lat-a.lat); const dLng=toRad(b.lng-a.lng);
  const s = Math.sin(dLat/2)**2 + Math.cos(toRad(a.lat))*Math.cos(toRad(b.lat))*Math.sin(dLng/2)**2;
  return 2*R*Math.asin(Math.sqrt(s));
}

function kmToMi(km:number){ return km * 0.621371; }

// Normalization helpers
function normMinMax(x:number, min:number, max:number){
  if (!Number.isFinite(x) || !Number.isFinite(min) || !Number.isFinite(max) || max <= min) return 0;
  return Math.max(0, Math.min(1, (x - min) / (max - min)));
}
function normInvDistance(mi:number, alpha=0.2){
  if (!Number.isFinite(mi) || mi < 0) return 0;
  return 1 / (1 + alpha * mi);
}

Deno.serve(async (req) => {
  try {
    const qs = new URL(req.url).searchParams;
    const lat = Number(qs.get("lat") ?? NaN);
    const lng = Number(qs.get("lng") ?? NaN);
    const radius_mi_qs = qs.get("radius_mi");
    const radius_km_qs = qs.get("radius_km");
    const radius_km = radius_mi_qs ? (Number(radius_mi_qs) * 1.60934) : Number(radius_km_qs ?? 25);
    if (!Number.isFinite(lat) || !Number.isFinite(lng)) return new Response(JSON.stringify({ error: "MISSING_COORDS" }), { status: 400, headers: { "content-type": "application/json" } });

    const supa = createClient(URL, ANON, { global: { headers: { Authorization: req.headers.get("Authorization") ?? "" } } });

    // Identify user (optional) and preferences for personalization
    let user_id: string | null = null;
    let prefs: { loyalty_brands?: string[]; amenity_priority?: Record<string, number> } = {};
    try {
      const { data } = await supa.auth.getUser();
      user_id = data?.user?.id ?? null;
      if (user_id){
        const { data: p } = await supa
          .from("user_preferences")
          .select("loyalty_brands, amenity_priority")
          .eq("user_id", user_id)
          .maybeSingle();
        if (p) prefs = p as any;
      }
    } catch {}

    // Fetch candidate locations + promos + org names
    const nowIso = new Date().toISOString();
    const [locs, promos, orgs] = await Promise.all([
      supa.from("locations").select("location_id,org_id,name,lat,lng"),
      supa
        .from("promotions")
        .select("id,org_id,location_id,title,description,type,value_cents,start_at,end_at,channels,is_active,locations,metadata")
        .lte("start_at", nowIso)
        .gte("end_at", nowIso)
        .eq("is_active", true),
      supa.from("orgs").select("org_id,name,slug")
    ]);
    if (locs.error) return new Response(JSON.stringify({ error: locs.error.message }), { status: 500, headers: { "content-type": "application/json" } });
    if (promos.error) return new Response(JSON.stringify({ error: promos.error.message }), { status: 500, headers: { "content-type": "application/json" } });

    const orgName = new Map<string,string>();
    for (const o of (orgs.data ?? []) as any[]) orgName.set(o.org_id, (o.name || o.slug || '').toString());

    // Precompute nearest location per promo/org within radius and attach stop metrics
    type Enriched = {
      promo: any;
      nearest: any | null;
      distance_km: number;
      distance_mi: number;
      parking_score: number; // from stop_scores.factors.parking
      confidence: number;    // from stop_confidence.confidence
      brand_loyalty_weight: number; // 0..1
      amenity_match: number; // 0..1
      fuel_discount_cents: number;  // derived from promo value for fuel discounts
      saved: boolean;
      badges: string[];
    };

    const locations = (locs.data ?? []) as any[];
    const candidates: Enriched[] = [];

    // Build nearest mapping per promo
    for (const p of (promos.data ?? []) as any[]) {
      // Determine candidate locations: scoped by promo.locations whitelist if provided
      let pool = locations.filter((x:any)=>x.org_id === p.org_id);
      const locScope = Array.isArray(p.locations) && p.locations.length ? new Set(p.locations as string[]) : null;
      if (locScope) pool = pool.filter((l:any)=> locScope.has(l.location_id));

      // Find nearest
      let bestKm = Infinity;
      let nearest: any = null;
      for (const l of pool){
        const d = haversineKm({lat, lng}, {lat: l.lat, lng: l.lng});
        if (d < bestKm){ bestKm = d; nearest = l; }
      }
      if (!nearest || bestKm > radius_km) continue; // outside radius or no location

      // Fetch stop confidence/score for nearest in bulk later; for now placeholders (we'll fill after bulk query)
      candidates.push({
        promo: p,
        nearest,
        distance_km: Math.round(bestKm * 10) / 10,
        distance_mi: Math.round(kmToMi(bestKm) * 10) / 10,
        parking_score: 0,
        confidence: 0,
        brand_loyalty_weight: 0,
        amenity_match: 0,
        fuel_discount_cents: 0,
        saved: false,
        badges: [],
      });
    }

    if (!candidates.length){
      return new Response(JSON.stringify({ ok: true, promos: [] }), { headers: { "content-type": "application/json" } });
    }

    // Bulk fetch stop scores/confidence for nearest locations
    const locIds = Array.from(new Set(candidates.map(c=>c.nearest.location_id)));
    const [{ data: scores }, { data: confs }] = await Promise.all([
      supa.from("stop_scores").select("location_id, factors, score").in("location_id", locIds),
      supa.from("stop_confidence").select("location_id, confidence").in("location_id", locIds),
    ]);
    const mapScore = new Map<string, any>();
    for (const s of (scores ?? []) as any[]) mapScore.set(s.location_id, s);
    const mapConf = new Map<string, number>();
    for (const c of (confs ?? []) as any[]) mapConf.set(c.location_id, (c as any).confidence ?? 0);

    // Loyalty weight: simple brand match against org name/slug
    const loy = new Set((prefs.loyalty_brands ?? []).map((s)=>String(s).toLowerCase()));

    // Amenity match: naive keyword match from user amenity_priority keys in promo title/description
    function amenityScore(p: any): number {
      const ap = (prefs.amenity_priority ?? {}) as Record<string, number>;
      const text = `${p.title ?? ''} ${p.description ?? ''}`.toLowerCase();
      let sum = 0, wsum = 0;
      for (const [k,v] of Object.entries(ap)){
        const kw = String(k).toLowerCase();
        const weight = Number(v) || 0;
        if (weight <= 0) continue;
        wsum += weight;
        if (kw && text.includes(kw)) sum += weight;
      }
      if (wsum <= 0) return 0;
      return Math.max(0, Math.min(1, sum / wsum));
    }

    // Derive per-candidate features
    for (const c of candidates){
      const s = mapScore.get(c.nearest.location_id);
      const conf = mapConf.get(c.nearest.location_id) ?? 0;
      c.parking_score = typeof s?.factors?.parking === 'number' ? s.factors.parking : (typeof s?.score === 'number' ? Math.max(0, Math.min(1, s.score)) : 0);
      c.confidence = conf;
      const brand = (orgName.get(c.nearest.org_id) || '').toLowerCase();
      c.brand_loyalty_weight = brand && loy.size ? (loy.has(brand) ? 1 : 0) : 0;
      c.amenity_match = amenityScore(c.promo);
      // Fuel discount cents: if promo.type indicates fuel and amount discount, use value_cents; percent treated as 0 for now
      c.fuel_discount_cents = (c.promo.type === 'amount') ? Number(c.promo.value_cents || 0) : 0;
    }

    // Min-max for fuel discounts present
    const vals = candidates.map(c=>c.fuel_discount_cents).filter((n)=>Number.isFinite(n)) as number[];
    const minF = vals.length ? Math.min(...vals) : 0;
    const maxF = vals.length ? Math.max(...vals) : 0;

    // Saved flag for the user (loyalty_wallet)
    if (user_id){
      const { data: savedList } = await supa.from("loyalty_wallet").select("promo_id").eq("user_id", user_id).in("promo_id", candidates.map(c=>c.promo.id));
      const savedSet = new Set((savedList ?? []).map((r:any)=>r.promo_id));
      for (const c of candidates){ c.saved = savedSet.has(c.promo.id); }
    }

    // Compute score and factors
    type Out = {
      promo_id: number;
      location_id: string;
      title: string;
      type: string;
      value_cents: number;
      distance_mi: number;
      parking_status: string;
      confidence: number;
      brand: string;
      badges: string[];
      channels: string[];
      score: number;
      factors: {
        parking: number;
        fuel: number;
        loyalty: number;
        amenities: number;
        distance: number;
        confidence: number;
      };
      metadata?: any;
    };

    const out: Out[] = candidates.map((c)=>{
      const f_discount = normMinMax(c.fuel_discount_cents, minF, maxF);
      const f_distance = normInvDistance(c.distance_mi, 0.2);
      const f_conf = Math.max(0, Math.min(1, c.confidence));
      const f_parking = Math.max(0, Math.min(1, c.parking_score));
      const f_loyalty = Math.max(0, Math.min(1, c.brand_loyalty_weight));
      const f_amenity = Math.max(0, Math.min(1, c.amenity_match));

      const weights = { parking: 0.35, fuel: 0.25, loyalty: 0.15, amenity: 0.15, distance: 0.10, confidence: 0.10 };
      const score = (
        weights.parking * f_parking +
        weights.fuel * f_discount +
        weights.loyalty * f_loyalty +
        weights.amenity * f_amenity +
        weights.distance * f_distance +
        weights.confidence * f_conf
      );

      // Determine a badge from top factor
      const pairs: Array<[string, number]> = [
        ["parking", f_parking], ["fuel", f_discount], ["loyalty", f_loyalty], ["amenities", f_amenity], ["distance", f_distance]
      ];
      pairs.sort((a,b)=>b[1]-a[1]);
      let primaryBadge = "Best Value";
      if (pairs[0][0] === "fuel") primaryBadge = "Cheapest fuel";
      else if (pairs[0][0] === "parking") primaryBadge = "Most parking now";
      else if (pairs[0][0] === "distance") primaryBadge = "Closest";
      else if (pairs[0][0] === "loyalty") primaryBadge = "Best for you";

      // Respect location-restricted promos: tag 'This stop only'
      if (Array.isArray(c.promo.locations) && c.promo.locations.length > 0){
        c.badges.push("This stop only");
      }

      const badges = [...new Set([primaryBadge, ...c.badges])];

      // Map parking score to a simple status
      const parking_status = f_parking >= 0.7 ? 'open' : (f_parking >= 0.4 ? 'limited' : 'full');

      // Lowercase channels
      const channels = Array.isArray(c.promo.channels) ? (c.promo.channels as any[]).map(x=>String(x).toLowerCase()) : [];

      const brand = orgName.get(c.nearest.org_id) || '';

      const outObj: Out = {
        promo_id: Number(c.promo.id),
        location_id: c.nearest.location_id,
        title: String(c.promo.title ?? ''),
        type: c.promo.type,
        value_cents: Number(c.promo.value_cents ?? 0),
        distance_mi: c.distance_mi,
        parking_status,
        confidence: Math.round(f_conf * 100) / 100,
        brand,
        badges,
        channels,
        score: Math.round(score * 100) / 100,
        factors: {
          parking: Math.round(f_parking * 100) / 100,
          fuel: Math.round(f_discount * 100) / 100,
          loyalty: Math.round(f_loyalty * 100) / 100,
          amenities: Math.round(f_amenity * 100) / 100,
          distance: Math.round(f_distance * 100) / 100,
          confidence: Math.round(f_conf * 100) / 100,
        },
      };
      if (c.promo.metadata) (outObj as any).metadata = c.promo.metadata;
      return outObj;
    });

    // Sort by score desc
    out.sort((a,b)=> (b.score - a.score) || (a.distance_mi - b.distance_mi));

    return new Response(JSON.stringify({ ok: true, promos: out }), { headers: { "content-type": "application/json" } });
  } catch (e) {
    return new Response(JSON.stringify({ error: String(e) }), { status: 500, headers: { "content-type": "application/json" } });
  }
});
