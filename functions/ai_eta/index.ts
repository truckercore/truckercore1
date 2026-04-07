// functions/ai_eta/index.ts
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
const URL = Deno.env.get("SUPABASE_URL")!;
const KEY = Deno.env.get("SUPABASE_SERVICE_ROLE")!;
const MODEL_URL = Deno.env.get("ETA_MODEL_URL")!; // hosted model endpoint

Deno.serve(async (req) => {
  try {
    const db = createClient(URL, KEY, { auth: { persistSession: false } });
    const body = await req.json(); // { org_id?, trip_id, features: {route_len_km, tod, traffic_idx, weather_code, start_utc} }
    if (!body || !body.trip_id || !body.features || !body.features.start_utc) {
      return new Response(JSON.stringify({ error: "bad_input" }), { status: 400, headers: { "content-type": "application/json" } });
    }
    const resp = await fetch(MODEL_URL, {
      method: "POST", headers: { "content-type": "application/json" },
      body: JSON.stringify(body.features)
    });
    if (!resp.ok) return new Response(JSON.stringify({ error: "model_error" }), { status: 502, headers: { "content-type": "application/json" } });
    const out = await resp.json(); // { eta_minutes: number }
    const etaUtc = new Date(new Date(body.features.start_utc).getTime() + out.eta_minutes*60*1000).toISOString();

    await db.from("ai_predictions").insert({
      org_id: body.org_id ?? null,
      module: "eta",
      subject_id: body.trip_id,
      features: body.features,
      prediction: { eta_utc: etaUtc, eta_minutes: out.eta_minutes }
    }, { returning: "minimal" });

    return new Response(JSON.stringify({ eta_utc: etaUtc, eta_minutes: out.eta_minutes }), { headers: { "content-type": "application/json" } });
  } catch (e) {
    return new Response(JSON.stringify({ error: String(e?.message ?? e) }), { status: 400, headers: { "content-type": "application/json" } });
  }
});
