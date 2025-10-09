import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { withIdempotency } from "./withIdempotency.ts";

const url = Deno.env.get("SUPABASE_URL")!;
const anon = Deno.env.get("SUPABASE_ANON")!;

function headers() {
  return { "Content-Type": "application/json", "Access-Control-Allow-Origin": "*" } as Record<string,string>;
}

async function coreHandler(req: Request): Promise<Response> {
  const supa = createClient(url, anon, { global: { headers: { Authorization: req.headers.get("Authorization") ?? "" }}});
  const body = await req.json().catch(()=>({}));
  // Minimal contract: { org_id, load_id, stop_sequence, predicted_eta, base_eta?, weather_delay_minutes?, traffic_delay_minutes?, model_version?, source?, explain? }
  if (!body?.org_id || !body?.load_id || !body?.stop_sequence || !body?.predicted_eta) {
    return new Response(JSON.stringify({ error: "missing required fields" }), { status: 400, headers: headers() });
  }
  const row = {
    org_id: body.org_id,
    load_id: body.load_id,
    stop_sequence: Number(body.stop_sequence),
    predicted_at: new Date().toISOString(),
    predicted_eta: new Date(body.predicted_eta).toISOString(),
    base_eta: body.base_eta ? new Date(body.base_eta).toISOString() : null,
    weather_delay_minutes: body.weather_delay_minutes ?? null,
    traffic_delay_minutes: body.traffic_delay_minutes ?? null,
    model_version: body.model_version ?? null,
    source: body.source ?? "webhook",
    explain: body.explain ?? null,
  };
  const { error } = await supa.from("eta_predictions").insert(row as any);
  if (error) return new Response(JSON.stringify({ error: error.message }), { status: 500, headers: headers() });
  return new Response(JSON.stringify({ ok: true }), { headers: headers() });
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: headers() });
  try {
    // Pass org id via header if provided in body to aid idempotency read scope
    let enrichedReq = req;
    try {
      const b = await req.clone().json().catch(()=>null);
      if (b?.org_id && !req.headers.get('X-Org-Id')) {
        const h = new Headers(req.headers);
        h.set('X-Org-Id', String(b.org_id));
        enrichedReq = new Request(req.url, { method: req.method, headers: h, body: await req.clone().text() });
      }
    } catch (_) {}
    return await withIdempotency(enrichedReq, () => coreHandler(enrichedReq));
  } catch (e) {
    return new Response(JSON.stringify({ error: String(e) }), { status: 500, headers: headers() });
  }
});