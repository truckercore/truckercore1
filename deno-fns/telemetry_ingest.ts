// deno-fns/telemetry_ingest.ts
// Telemetry ingestion: server-side rounding/validation and bulk insert to gps_samples.
// Requires env: SUPABASE_URL, SUPABASE_SERVICE_ROLE

import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
const db = createClient(Deno.env.get("SUPABASE_URL")!, Deno.env.get("SUPABASE_SERVICE_ROLE")!);

function round4(x: number) { return Math.round(x * 1e4) / 1e4; }

Deno.serve(async (req) => {
  if (req.method !== "POST") return new Response("method", { status: 405 });
  const auth = req.headers.get("Authorization") ?? "";
  // TODO: validate session, get user_id/org_id
  const { coarse = false, samples = [] } = await req.json().catch(()=>({}));

  const rows: any[] = [];
  for (const s of samples) {
    if (typeof s.lat !== "number" || typeof s.lng !== "number") continue;
    const lat = coarse ? round4(s.lat) : s.lat;
    const lng = coarse ? round4(s.lng) : s.lng;
    const acc = Math.min(Math.max(Number(s.accuracy_m ?? 50), 5), 200); // clamp 5..200m
    const speed = Number(s.speed_kph ?? 0);
    if (speed < 0 || speed > 150) continue; // discard implausible
    const ts = s.ts ? new Date(s.ts).toISOString() : new Date().toISOString();
    rows.push({
      lat, lng,
      speed_kph: speed,
      heading_deg: Math.round(Number(s.heading ?? 0)),
      accuracy_m: acc,
      source: "mobile",
      ts
    });
  }

  if (!rows.length) return new Response(JSON.stringify({ accepted: 0 }), { headers: { "content-type": "application/json" } });

  const { error } = await db.from("gps_samples").insert(rows);
  if (error) return new Response(error.message, { status: 500 });
  return new Response(JSON.stringify({ accepted: rows.length }), { headers: { "content-type": "application/json" } });
});
