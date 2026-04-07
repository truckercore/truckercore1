// functions/ai_match/index.ts
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
const URL = Deno.env.get("SUPABASE_URL")!;
const KEY = Deno.env.get("SUPABASE_SERVICE_ROLE")!;
const MODEL_URL = Deno.env.get("MATCH_MODEL_URL")!; // ranking/classifier API

Deno.serve(async (req) => {
  try {
    const db = createClient(URL, KEY, { auth: { persistSession: false } });
    const body = await req.json(); // { org_id?, load_id, driver_id, features: {...} }
    if (!body || !body.load_id || !body.driver_id || !body.features) {
      return new Response(JSON.stringify({ error: "bad_input" }), { status: 400, headers: { "content-type": "application/json" } });
    }
    const resp = await fetch(MODEL_URL, { method: "POST", headers: { "content-type": "application/json" }, body: JSON.stringify(body.features) });
    if (!resp.ok) return new Response(JSON.stringify({ error: "model_error" }), { status: 502, headers: { "content-type": "application/json" } });
    const out = await resp.json(); // { score: 0..1, label?: 'likely'|'unlikely' }

    await db.from("ai_predictions").insert({
      org_id: body.org_id ?? null,
      module: "match",
      subject_id: `${body.load_id}:${body.driver_id}`,
      features: body.features,
      prediction: out
    }, { returning: "minimal" });

    return new Response(JSON.stringify(out), { headers: { "content-type": "application/json" } });
  } catch (e) {
    return new Response(JSON.stringify({ error: String(e?.message ?? e) }), { status: 400, headers: { "content-type": "application/json" } });
  }
});
