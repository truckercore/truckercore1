import { createClient } from "https://esm.sh/@supabase/supabase-js@2.46.1";

const ok = (b: unknown) =>
  new Response(JSON.stringify(b), {
    headers: {
      "content-type": "application/json",
      "access-control-allow-origin": "*",
    },
  });

Deno.serve(async (req) => {
  try {
    const sb = createClient(
      Deno.env.get("SUPABASE_URL")!,
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!
    );
    const { minutes = 1440 } = await req.json().catch(() => ({}));
    const { data, error } = await sb.rpc("ai_eta_rca", {
      minutes_back: minutes,
    });
    if (error) {
      return ok({ error: error.message });
    }
    return ok({ cohorts: data });
  } catch (e) {
    return ok({ error: String(e?.message ?? e) });
  }
});
