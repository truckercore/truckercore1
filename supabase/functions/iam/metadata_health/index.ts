// functions/iam/metadata_health/index.ts
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.46.1";
import { loadDecisions } from "../../_lib/decisions.ts";

function json(b: unknown, s = 200) {
  return new Response(JSON.stringify(b), { status: s, headers: { "content-type": "application/json" } });
}

Deno.serve(async (req) => {
  try {
    const url = new URL(req.url);
    const org_id = url.searchParams.get("org_id") ?? undefined;

    const sb = createClient(
      Deno.env.get("SUPABASE_URL")!,
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!
    );

    const { data: health, error } = await sb
      .from("iam_idp_health")
      .select("*")
      .eq("org_id", org_id)
      .maybeSingle();
    if (error) return json({ error: error.message }, 500);

    // Build canary banner from decisions thresholds
    const dec = await loadDecisions(org_id);
    let banner: { level: "red" | "yellow"; msg: string } | null = null;
    if (health?.cert_expires_at) {
      const days = Math.ceil((new Date(health.cert_expires_at).getTime() - Date.now()) / 86400000);
      if (days <= dec.iam.idp_health.red_days) {
        banner = { level: "red", msg: `SSO cert expires in ${days} day(s). Renew now.` };
      } else if (days <= dec.iam.idp_health.yellow_days) {
        banner = { level: "yellow", msg: `SSO cert expires in ${days} day(s). Plan renewal.` };
      }
    }

    return json({ health, banner });
  } catch (e) {
    return json({ error: String(e?.message ?? e) }, 500);
  }
});
