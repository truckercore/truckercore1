// deno-fns/ingest_noaa.ts
// Deno Edge cron (ingest NOAA alerts) into unified hazards table via RPC
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
const url = Deno.env.get("SUPABASE_URL")!, key = Deno.env.get("SUPABASE_SERVICE_ROLE")!;
const noaa = Deno.env.get("NOAA_ALERTS_URL") ?? "https://api.weather.gov/alerts/active?status=actual";

Deno.serve(async () => {
  const db = createClient(url, key, { auth: { persistSession: false } });
  const res = await fetch(noaa, { headers: { "User-Agent": "TruckerCore Hazards", "accept": "application/geo+json" } });
  if (!res.ok) return new Response(`fetch ${res.status}`, { status: 500 });
  const gj = await res.json();

  const rows: any[] = [];
  for (const f of (gj.features ?? [])) {
    const props = f.properties ?? {};
    const g = f.geometry ?? (props?.geometry ?? null);
    if (!g) continue;
    rows.push({
      ext_id: String(props.id ?? f.id ?? crypto.randomUUID()),
      source: 'noaa',
      kind: (props.event || 'weather').toString().toLowerCase(), // e.g., 'flood warning'
      severity: (props.severity || null),
      title: props.headline || props.event || null,
      description: props.description || props.instruction || null,
      starts_at: props.onset || props.effective || null,
      ends_at: props.expires || props.ends || null,
      observed_at: props.sent || new Date().toISOString(),
      geom: g,
      metadata: props
    });
  }

  const { error } = await db.rpc('hazards_upsert_geojson', { p_rows: rows });
  if (error) return new Response(error.message, { status: 500 });
  return new Response('ok');
});
