import { createClient } from "https://esm.sh/@supabase/supabase-js@2.46.1";

Deno.serve(async (req) => {
  if (req.method !== "POST") return new Response("method", { status: 405 });

  try {
    const sb = createClient(
      Deno.env.get("SUPABASE_URL")!,
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!
    );
    const { vehicle_id, features } = await req.json();

    const url = Deno.env.get("MAINT_MODEL_ENDPOINT")!;
    const res = await fetch(url, {
      method: "POST",
      headers: { "content-type": "application/json" },
      body: JSON.stringify(features),
    });
    if (!res.ok) {
      return new Response("model_error", { status: 502 });
    }
    const pred = await res.json(); // { risk: number, horizon_days: number }

    const { data: ver } = await sb
      .from("ai_model_versions")
      .select("id")
      .eq("status", "active")
      .limit(1)
      .maybeSingle();

    await sb.from("maintenance_predictions").insert({
      vehicle_id,
      model_version_id: ver?.id ?? null,
      failure_risk: pred.risk,
      horizon_days: pred.horizon_days,
    });

    return new Response(JSON.stringify(pred), {
      headers: {
        "content-type": "application/json",
        "access-control-allow-origin": "*",
      },
    });
  } catch {
    return new Response("error", { status: 500 });
  }
});
