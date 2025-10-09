import { createClient } from "https://esm.sh/@supabase/supabase-js@2.46.1";

Deno.serve(async (req) => {
  const url = new URL(req.url);
  const dry = url.searchParams.get("dry") === "1";
  const sb = createClient(
    Deno.env.get("SUPABASE_URL")!,
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!
  );

  if (dry) {
    const { data: rows } = await sb
      .from("ai_model_rollouts")
      .select("model_key, status, pct")
      .eq("status", "canary");
    return new Response(
      JSON.stringify({ ok: true, dry: true, candidates: rows || [] }),
      { headers: { "content-type": "application/json" } }
    );
  }

  const { error } = await sb.rpc("ai_auto_promote_check");
  const ok = !error;
  const ts = new Date().toISOString();
  console.log(JSON.stringify({ mod: "promoctl", action: "auto_step", ok, ts }));
  return new Response(
    JSON.stringify({ ok, stepped: true, ts }),
    { headers: { "content-type": "application/json" }, status: ok ? 200 : 500 }
  );
});
