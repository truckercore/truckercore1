// functions/_lib/entitlement.ts
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.46.1";

export async function requireEntitlement(org_id: string, feature: string) {
  const sb = createClient(
    Deno.env.get("SUPABASE_URL")!,
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!
  );
  const { data, error } = await sb.rpc("entitlements_check", { p_org: org_id, p_feature: feature });
  if (error) return false;
  return data === true;
}
