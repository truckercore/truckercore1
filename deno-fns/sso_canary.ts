// deno-fns/sso_canary.ts
// Schedules: weekly per IdP/org (or staggered daily across orgs)
// Canary performs metadata discovery and JWKS fetch to detect obvious config or rotation issues.
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const SERVICE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE")!;
const db = createClient(SUPABASE_URL, SERVICE_KEY, { auth: { persistSession: false }});

// Simple rate-limit (avoid stampede)
function jitter(ms: number) { return new Promise(r => setTimeout(r, ms + Math.floor(Math.random()*5000))); }

Deno.serve(async (_req) => {
  // 1) Fetch orgs with SSO enabled (service query to your sso configs)
  const { data: orgs, error } = await db
    .from("sso_configs")
    .select("org_id, idp, issuer, client_id")
    .eq("enabled", true);
  if (error) return new Response(error.message, { status: 500 });

  for (const o of orgs ?? []) {
    await jitter(250);
    try {
      // 2) Perform metadata discovery check only (no real login)
      const wellKnown = `${String(o.issuer).replace(/\/$/, "")}/.well-known/openid-configuration`;
      const res = await fetch(wellKnown, { /* deno deploy supports timeout via AbortSignal */ } as any);
      if (!res.ok) throw new Error(`discovery_${res.status}`);
      const meta = await res.json();
      if (!meta.authorization_endpoint || !meta.token_endpoint || !meta.jwks_uri) throw new Error("missing_endpoints");

      // 3) Optionally hit JWKS to detect key rotation problems
      const jwks = await fetch(String(meta.jwks_uri), { } as any);
      if (!jwks.ok) throw new Error(`jwks_${jwks.status}`);

      // 4) Mark success
      await db.rpc("fn_sso_mark_success", { p_org_id: o.org_id, p_idp: o.idp });
    } catch (e) {
      await db.rpc("fn_sso_mark_error", {
        p_org_id: o.org_id,
        p_idp: o.idp,
        p_code: String((e as any)?.message ?? "canary_error"),
      });
    }
  }

  return new Response("ok");
});
