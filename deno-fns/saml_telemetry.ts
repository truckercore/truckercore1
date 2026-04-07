// deno-fns/saml_telemetry.ts
// Helper to record SAML login outcomes into alerts_events as SAML_LOGIN entries.
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const URL = Deno.env.get("SUPABASE_URL")!;
const KEY = Deno.env.get("SUPABASE_SERVICE_ROLE")!;
export const db = createClient(URL, KEY, { auth: { persistSession: false }});

export async function recordSamlLogin(orgId: string, idp: string, ok: boolean, ms: number, reason?: string, roles?: string[]) {
  try {
    await db.from("alerts_events").insert({
      org_id: orgId,
      severity: ok ? "INFO" : "WARN",
      code: "SAML_LOGIN",
      payload: { idp, ok, ms, reason, roles }
    } as any);
  } catch (_) {
    // best-effort only
  }
}
