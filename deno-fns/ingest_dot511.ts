// deno-fns/ingest_dot511.ts
// Deno Edge cron (ingest DOT 511)
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
const url = Deno.env.get("SUPABASE_URL")!, key = Deno.env.get("SUPABASE_SERVICE_ROLE")!;
const feed = Deno.env.get("DOT511_FEED_URL")!; // GeoJSON

Deno.serve(async () => {
  const db = createClient(url, key, { auth: { persistSession: false } });
  const res = await fetch(feed);
  if (!res.ok) return new Response(`fetch ${res.status}`, { status: 500 });
  const gj = await res.json();

  const rows: any[] = [];
  for (const f of (gj.features ?? [])) {
    const props = f.properties ?? {};
    const g = f.geometry;
    if (!g) continue;
    rows.push({
      ext_id: String(props.id ?? f.id ?? props.eventId ?? props.event_id ?? crypto.randomUUID()),
      source: 'dot511',
      kind: (props.eventType || 'incident').toString().toLowerCase(),
      severity: (props.severity || null),
      title: props.headline || props.event || null,
      description: props.description || null,
      starts_at: props.startTime ? new Date(props.startTime).toISOString() : null,
      ends_at: props.endTime ? new Date(props.endTime).toISOString() : null,
      observed_at: new Date().toISOString(),
      geom: g, // pass GeoJSON; RPC will convert
      metadata: props
    });
  }

  // Upsert via SQL RPC that accepts jsonb[] and handles ST_GeomFromGeoJSON
  const { error } = await db.rpc('hazards_upsert_geojson', { p_rows: rows });
  if (error) return new Response(error.message, { status: 500 });
  return new Response('ok');
});
