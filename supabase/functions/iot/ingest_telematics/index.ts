// functions/iot/ingest_telematics/index.ts
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
const ok = (b:unknown,s=200)=>new Response(JSON.stringify(b),{status:s,headers:{'content-type':'application/json','access-control-allow-origin':'*'}});
Deno.serve(async (req) => {
  if (req.method !== "POST") return ok({error:"method"},405);
  const { vendor, org_id, payload } = await req.json();
  const sb = createClient(Deno.env.get("SUPABASE_URL")!, Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!);

  const { data: mapRow, error: mapErr } = await sb.from("telematics_vendor_adapters")
    .select("mapping,enabled").eq("vendor", vendor).maybeSingle();
  if (mapErr) return ok({error: mapErr.message},400);
  if (!mapRow?.enabled) return ok({error:"vendor_disabled"},403);

  const recs = Array.isArray(payload) ? payload : [payload];
  const rows = recs.map((p:any)=>({
    org_id,
    driver_id: p.driver_id ?? p.driverId ?? null,
    vehicle_id: p.vehicle_id ?? p.vehicleId ?? null,
    ts: new Date(p.timestamp || p.ts || Date.now()).toISOString(),
    lat: p.lat ?? p.location?.lat ?? null,
    lon: p.lon ?? p.location?.lon ?? null,
    speed_mph: p.speed ?? p.speed_mph ?? null,
    brake: !!(p.hard_brake || p.brake),
    rpm: p.rpm ?? null,
    engine_on: p.engine_on ?? p.ignition ?? null,
    ecu: p.ecu || {},
    src_vendor: vendor,
    raw: p
  }));

  const { error } = await sb.from("raw_telematics").insert(rows);
  if (error) return ok({error:error.message},400);
  return ok({ok:true, inserted: rows.length});
});
