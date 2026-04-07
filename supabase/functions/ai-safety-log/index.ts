import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const url = Deno.env.get("SUPABASE_URL")!;
const anon = Deno.env.get("SUPABASE_ANON")!;

function headers() { return { "Content-Type": "application/json", "Access-Control-Allow-Origin": "*" }; }

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: headers() });
  if (req.method !== "POST") return new Response("method", { status: 405, headers: headers() });
  try {
    const supa = createClient(url, anon, { global: { headers: { Authorization: req.headers.get("Authorization") ?? "" }}});
    const body = await req.json().catch(()=>({}));
    // Minimal contract: { org_id, user_id?, event_kind, feature, input_tokens?, output_tokens?, model_name?, cost_usd?, detail? }
    if (!body?.org_id || !body?.event_kind || !body?.feature) {
      return new Response(JSON.stringify({ error: "missing required fields" }), { status: 400, headers: headers() });
    }
    const row = {
      org_id: body.org_id,
      user_id: body.user_id ?? null,
      event_kind: body.event_kind,
      feature: body.feature,
      input_tokens: body.input_tokens ?? null,
      output_tokens: body.output_tokens ?? null,
      model_name: body.model_name ?? null,
      cost_usd: body.cost_usd ?? null,
      detail: body.detail ?? null,
    } as const;
    const { error } = await supa.from("ai_safety_events").insert(row as any);
    if (error) return new Response(JSON.stringify({ error: error.message }), { status: 500, headers: headers() });
    return new Response(JSON.stringify({ ok: true }), { headers: headers() });
  } catch (e) {
    return new Response(JSON.stringify({ error: String(e) }), { status: 500, headers: headers() });
  }
});