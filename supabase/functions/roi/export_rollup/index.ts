import { requireEntitlement } from "../../_lib/entitlement.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

export default async function handler(req: Request) {
  const url = new URL(req.url);
  const org_id = url.searchParams.get("org_id") ?? "";
  if (!org_id) return new Response(JSON.stringify({ error: "missing org_id" }), { status: 400, headers: { "content-type": "application/json" } });

  if (!(await requireEntitlement(org_id, "exec_analytics"))) {
    return new Response(JSON.stringify({ error: "forbidden", feature: "exec_analytics", message: "Ask your admin to enable Executive Analytics in Entitlements." }), { status: 403, headers: { "content-type": "application/json" } });
  }

  const sb = createClient(Deno.env.get("SUPABASE_URL")!, Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!, { auth: { persistSession: false } });

  const { data, error } = await sb.from("ai_roi_rollup_day").select("*").eq("org_id", org_id).order("day", { ascending: false });
  if (error) return new Response(JSON.stringify({ error: error.message }), { status: 500, headers: { "content-type": "application/json" } });

  const since = new Date(Date.now() - 90 * 864e5).toISOString();
  const { data: baselines } = await sb
    .from("ai_roi_baselines")
    .select("key,value,effective_at")
    .eq("org_id", org_id)
    .gte("effective_at", since);

  const { data: meta } = await sb.from("ai_roi_rollup_meta").select("last_refresh_at").maybeSingle();

  return new Response(JSON.stringify({ rows: data || [], baselines: baselines || [], last_refresh_at: meta?.last_refresh_at || null }), {
    headers: { "content-type": "application/json" }
  });
}

// Ensure it's served by Deno
Deno.serve(handler);
