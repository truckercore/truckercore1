// TypeScript
import { createClient } from "@/lib/supabase/client";

export async function checkQuota(orgId: string, feature: string, qty: number) {
  const supabase = createClient();
  const { data: org, error: e1 } = await supabase.from("orgs").select("plan").eq("id", orgId).single();
  if (e1) throw e1;
  const { data: plan, error: e2 } = await supabase.from("plan_quotas").select("quotas").eq("plan", (org as any)?.plan ?? "free").single();
  if (e2) throw e2;
  const { data: used, error: e3 } = await supabase.rpc("sum_usage", { p_org: orgId, p_feature: feature });
  if (e3) throw e3;
  const limit = (plan?.quotas as any)?.[feature] ?? 0;
  if (Number(used ?? 0) + qty > Number(limit)) throw new Error("quota_exceeded");
}
