// supabase/functions/ads-nearby/index.ts
// Returns nearby, currently-active ads filtered by role and per-ad radius, logs impressions, and
// responds with tracking tokens for click-through attribution.

import "jsr:@supabase/functions-js/edge-runtime";
import { createClient } from "npm:@supabase/supabase-js@2";

// Early environment validation
const required = ["SUPABASE_URL", "SUPABASE_SERVICE_ROLE_KEY"] as const;
const missing = required.filter((k) => !Deno.env.get(k));
if (missing.length) {
  console.error(`[startup] Missing required envs: ${missing.join(', ')}`);
  throw new Error("Configuration error: missing required environment variables");
}
const svc = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
if (!/^([A-Za-z0-9\._\-]{20,})$/.test(svc)) {
  console.warn("[startup] SUPABASE_SERVICE_ROLE_KEY format looks unusual");
}

const supabase = createClient(
  Deno.env.get("SUPABASE_URL")!,
  Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
  { auth: { persistSession: false } },
);

type Claims = { sub?: string; app_is_premium?: string; [k: string]: unknown };

function parseJwt<T = Claims>(authz: string | null): T | null {
  try {
    if (!authz) return null;
    const token = authz.replace(/^Bearer\s+/i, '').trim();
    const parts = token.split('.');
    if (parts.length !== 3) return null;
    const json = atob(parts[1].replace(/-/g, '+').replace(/_/g, '/'));
    return JSON.parse(json) as T;
  } catch {
    return null;
  }
}

function haversine(lat1:number, lon1:number, lat2:number, lon2:number) {
  const R=6371; const dLat=(lat2-lat1)*Math.PI/180; const dLon=(lon2-lon1)*Math.PI/180;
  const a=Math.sin(dLat/2)**2+Math.cos(lat1*Math.PI/180)*Math.cos(lat2*Math.PI/180)*Math.sin(dLon/2)**2;
  return 2*R*Math.asin(Math.sqrt(a));
}

Deno.serve(async (req: Request) => {
  try {
    if (req.method !== 'POST') {
      return new Response(JSON.stringify({ error: 'METHOD_NOT_ALLOWED' }), { status: 405, headers: { 'Content-Type': 'application/json' } });
    }
    const body = await req.json().catch(() => ({}));
    const lat = Number(body?.lat);
    const lng = Number(body?.lng);
    const role = String(body?.role ?? 'driver').toLowerCase();
    const radiusKm = Math.max(1, Math.min(250, Number(body?.radius_km ?? 25)));
    const deviceHash = typeof body?.device_hash === 'string' ? body.device_hash : null;

    if (!isFinite(lat) || !isFinite(lng)) {
      return new Response(JSON.stringify({ error: 'lat,lng required' }), { status: 400, headers: { 'Content-Type': 'application/json' } });
    }

    // active window filter
    const nowIso = new Date().toISOString();

    // Fetch candidate ads (time + role match). We’ll distance filter below.
    const { data: ads, error } = await supabase
      .from("ads")
      .select("*")
      .lte("active_from", nowIso) // <= now
      .gte("active_to", nowIso)   // >= now
      .order("priority", { ascending: false });

    if (error) {
      return new Response(JSON.stringify({ error: error.message }), { status: 500, headers: { "Content-Type": "application/json" } });
    }

    // Fetch nearby stops via RPC to avoid unbounded scans; build id->coords map for radius filtering
    const stopsById: Record<string, { lat: number; lng: number }> = {};
    const { data: nearStops, error: nearErr } = await supabase.rpc('nearest_truckstops', {
      p_lat: lat,
      p_lng: lng,
      p_radius_km: radiusKm,
      p_limit: 1000,
    });
    if (!nearErr) {
      for (const s of (nearStops as any[] ?? [])) stopsById[s.id] = { lat: s.lat, lng: s.lng };
    }

    // Filter by role & per-ad radius (fallback to query radius) & optional time windows
    const filtered = (ads ?? []).filter((ad: any) => {
      const t = ad.target_json ?? {};
      const roles: string[] = Array.isArray(t.roles) ? t.roles.map((r: string) => String(r).toLowerCase()) : [];
      const roleOk = roles.length === 0 || roles.includes(role);

      // Use ad-specific radius if provided; else use query radius
      const adRadiusKm = typeof t.radius_km === "number" && isFinite(t.radius_km) ? t.radius_km : radiusKm;

      let distanceOk = true;
      if (ad.stop_id && stopsById[ad.stop_id]) {
        const s = stopsById[ad.stop_id];
        const dKm = haversine(lat, lng, s.lat, s.lng);
        distanceOk = dKm <= adRadiusKm;
      }

      return roleOk && distanceOk;
    });

    // Deduplicate by stop_id (prefer highest priority)
    const seen = new Set<string>();
    const deduped: any[] = [];
    for (const ad of filtered) {
      const key = ad.stop_id ?? ad.id;
      if (!seen.has(key)) {
        seen.add(key);
        deduped.push(ad);
      }
    }

    // Asynchronously create impressions (one per returned ad)
    const claims = parseJwt<Claims>(req.headers.get("Authorization"));
    const userId = (claims?.sub as string) ?? null;

    const impressionsPayload = deduped.map(ad => ({
      ad_id: ad.id,
      user_id: userId,
      device_hash: deviceHash,
      lat, lng
    }));

    // Insert impressions and return tracking tokens with ads; never fail the whole response on impression errors
    const { data: imps, error: impErr } = await supabase
      .from("ad_impressions")
      .insert(impressionsPayload, { count: "none" })
      .select("ad_id, tracking_token");

    const tokenByAd: Record<string, string> = {};
    if (!impErr && imps) {
      for (const row of imps) tokenByAd[row.ad_id] = row.tracking_token;
    }

    const out = deduped.map(ad => ({
      id: ad.id,
      stop_id: ad.stop_id,
      title: ad.title,
      body: ad.body,
      media_url: ad.media_url,
      cta_text: ad.cta_text,
      cta_url: ad.cta_url,
      priority: ad.priority,
      sponsored: true,
      tracking_token: tokenByAd[ad.id] ?? null
    }));

    return new Response(JSON.stringify(out), { headers: { "Content-Type": "application/json" } });
  } catch (e) {
    return new Response(JSON.stringify({ error: String(e) }), { status: 500, headers: { 'Content-Type': 'application/json' } });
  }
});
