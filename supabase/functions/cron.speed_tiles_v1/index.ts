// Supabase Edge Function (scheduled): cron.speed_tiles_v1
// Buckets recent GPS samples into WebMercator tiles at a chosen zoom and hour bucket.
// Env:
//  - SPEED_WINDOW_MIN (default 15)
//  - SPEED_TILE_ZOOM (default 12)
// Tables:
//  - tiles_speed_agg(tile_id text, hour_bucket timestamptz, mean_speed numeric, p95_delay numeric, samples int)

import "jsr:@supabase/functions-js/edge-runtime";
import { createClient } from "npm:@supabase/supabase-js@2";

const URL = Deno.env.get("SUPABASE_URL")!;
const SERVICE = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
const WINDOW_MIN = Number(Deno.env.get("SPEED_WINDOW_MIN") ?? 15);
const ZOOM = Number(Deno.env.get("SPEED_TILE_ZOOM") ?? 12);

// simple WebMercator tile helper
function lon2x(lon: number) { return (lon + 180) / 360; }
function lat2y(lat: number) {
  const s = Math.sin((lat * Math.PI)/180);
  return (0.5 - Math.log((1+s)/(1-s))/(4*Math.PI));
}
function tileId(z: number, x: number, y: number) { return `${z}/${x}/${y}`; }
function tileXY(lat: number, lon: number, z: number) {
  const n = Math.pow(2, z);
  const x = Math.floor(lon2x(lon) * n);
  const y = Math.floor(lat2y(lat) * n);
  return { x, y };
}

Deno.serve(async (_req) => {
  const started = Date.now();
  try {
    const db = createClient(URL, SERVICE);
    const sinceIso = new Date(Date.now() - WINDOW_MIN*60*1000).toISOString();

    // 1) pull recent gps samples
    const { data: rows, error } = await db
      .from("gps_samples")
      .select("lat,lng,speed_kph,ts")
      .gte("ts", sinceIso)
      .limit(200000);
    if (error) return new Response(JSON.stringify({ error: error.message }), { status: 500, headers: { 'content-type':'application/json' } });

    // 2) bucket by tile and hour
    const byTile = new Map<string, number[]>();
    const now = new Date();
    const hourBucket = new Date(Date.UTC(now.getUTCFullYear(), now.getUTCMonth(), now.getUTCDate(), now.getUTCHours(), 0, 0)).toISOString();
    for (const r of rows ?? []) {
      const lat = (r as any).lat as number;
      const lng = (r as any).lng as number;
      if (typeof lat !== 'number' || typeof lng !== 'number') continue;
      const { x, y } = tileXY(lat, lng, ZOOM);
      const id = tileId(ZOOM, x, y) + "@" + hourBucket;
      if (!byTile.has(id)) byTile.set(id, []);
      const speed = typeof (r as any).speed_kph === 'number' ? (r as any).speed_kph : 0;
      if (Number.isFinite(speed) && speed >= 0 && speed <= 140) byTile.get(id)!.push(speed);
    }

    let updated = 0;
    // 3) compute stats and upsert
    for (const [id, speeds] of byTile.entries()) {
      const [zxy, hour] = id.split("@");
      // const [z, x, y] = zxy.split("/").map(Number); // not used beyond id
      if (speeds.length < 5) continue;
      speeds.sort((a,b)=>a-b);
      const mean = speeds.reduce((a,b)=>a+b,0)/speeds.length;
      const p95 = speeds[Math.floor(0.95 * (speeds.length-1))];
      const max = speeds[speeds.length-1];

      const { error: upErr } = await db
        .from("tiles_speed_agg")
        .upsert({
          tile_id: zxy,
          hour_bucket: hour,
          mean_speed: Math.round(mean*10)/10,
          p95_delay: Math.max(0, Math.round((max - mean))),
          samples: speeds.length
        }, { onConflict: "tile_id,hour_bucket" });
      if (!upErr) updated++;
      else console.error("tile upsert error", zxy, upErr.message);
    }

    const duration_ms = Date.now() - started;
    return new Response(JSON.stringify({ ok: true, window_min: WINDOW_MIN, zoom: ZOOM, buckets: byTile.size, updated, duration_ms }), { headers: { 'content-type':'application/json' } });
  } catch (e) {
    return new Response(JSON.stringify({ error: String(e) }), { status: 500, headers: { 'content-type':'application/json' } });
  }
});