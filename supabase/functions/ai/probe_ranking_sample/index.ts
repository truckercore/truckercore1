import { createClient } from "https://esm.sh/@supabase/supabase-js@2.46.1";
import { loadDecisions } from "../../_lib/decisions.ts";

Deno.serve(async (req) => {
  try {
    const org_id = new URL(req.url).searchParams.get("org_id");
    if (!org_id) return new Response(JSON.stringify({ ok: false, error: "missing_org_id" }), { status: 400, headers: { "content-type": "application/json" } });
    const dec = await loadDecisions(org_id);
    const sb = createClient(Deno.env.get("SUPABASE_URL")!, Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!);
    const factors = Object.fromEntries((dec.ai.ranking.required_factors || []).map((f: string) => [f, Math.random()]));
    const { error } = await sb.from("ai_rank_factors").insert({
      org_id,
      model_key: "probe",
      model_version: "v0",
      request_id: crypto.randomUUID(),
      item_id: "test",
      rank: 1,
      score: 1.0,
      factors
    });
    if (error) return new Response(JSON.stringify({ ok: false, error: error.message }), { status: 500, headers: { "content-type": "application/json" } });
    return new Response(JSON.stringify({ ok: true }), { headers: { "content-type": "application/json" } });
  } catch (e) {
    return new Response(JSON.stringify({ ok: false, error: String(e) }), { status: 500, headers: { "content-type": "application/json" } });
  }
});
