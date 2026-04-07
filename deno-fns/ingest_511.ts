// deno-fns/ingest_511.ts
// DOT 511 ingest skeleton: fetch per-state GeoJSON endpoints and upsert into road_closures.
// Requires env: SUPABASE_URL, SUPABASE_SERVICE_ROLE

import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const db = createClient(Deno.env.get("SUPABASE_URL")!, Deno.env.get("SUPABASE_SERVICE_ROLE")!);

type DotFeature = { id: string; properties: any; geometry: any };

async function fetchState511(url: string, state: string, sourceKey: string) {
  const res = await fetch(url, { headers: { "accept": "application/json" } });
  if (!res.ok) throw new Error(`511_${state}_${res.status}`);
  const gj = await res.json();
  const feats: DotFeature[] = gj.features ?? [];
  for (const f of feats) {
    const p = f.properties ?? {};
    const extId = String(p.id ?? f.id ?? p.event_id ?? crypto.randomUUID());
    const start = p.start ?? p.starttime ?? p.start_time;
    const end = p.end ?? p.endtime ?? p.end_time;
    const sev = (p.severity ?? p.impact ?? "unknown").toString().toLowerCase();
    const cause = (p.cause ?? p.category ?? p.type ?? "unknown").toString().toLowerCase();
    const lanes = p.lanes ?? p.laneImpact ?? null;
    const ttlMinutes = 180; // default 3h
    const expiresAt = new Date(Date.now() + ttlMinutes * 60000).toISOString();

    const row = {
      source: sourceKey,
      ext_id: extId,
      state,
      geometry: f.geometry,            // store raw GeoJSON
      start_time: start ? new Date(start).toISOString() : null,
      end_time: end ? new Date(end).toISOString() : null,
      lanes,
      severity: ["minor","moderate","major"].includes(sev) ? sev : "unknown",
      cause,
      last_seen: new Date().toISOString(),
      expires_at: expiresAt,
      meta: p
    } as const;

    const { error } = await db.from("road_closures").upsert(row as any, { onConflict: "source,ext_id" });
    if (error) console.error("upsert 511", state, extId, error.message);
  }
}

Deno.serve(async () => {
  // TODO: Replace example URL(s) with real 511 endpoints
  const tasks = [
    fetchState511("https://example.511.state/geojson/closures", "WA", "wa_511"),
  ];
  await Promise.allSettled(tasks);
  // GC: delete expired
  try {
    await db.rpc("gc_expired_511");
  } catch (_) {}
  return new Response("ok");
});
