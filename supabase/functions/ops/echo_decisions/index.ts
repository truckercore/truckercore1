// functions/ops/echo_decisions/index.ts
import { loadDecisions } from "../../_lib/decisions.ts";

function isAdmin(jwt: any): boolean {
  try {
    const roles = (jwt?.app_roles ?? []) as string[];
    return Array.isArray(roles) && roles.includes("corp_admin");
  } catch {
    return false;
  }
}

// Wrapper used by OPA guard check
function requireAdmin(jwt: any): boolean {
  return isAdmin(jwt);
}

Deno.serve(async (req) => {
  try {
    const auth = req.headers.get("authorization") || "";
    const jwt = auth.startsWith("Bearer ") ? JSON.parse(atob(auth.split(".")[1])) : null;
    if (!requireAdmin(jwt)) {
      return new Response(JSON.stringify({ error: "forbidden" }), { status: 403, headers: { "content-type": "application/json" } });
    }

    const org_id = new URL(req.url).searchParams.get("org_id") || undefined;
    const dec = await loadDecisions(org_id);

    return new Response(
      JSON.stringify({
        iam: {
          jwks_ttl: dec.iam.jwks_ttl,
          invalidate_on: dec.iam.invalidate_on,
          scim: {
            bulk_deactivate_cap: dec.iam.scim.bulk_deactivate_cap,
            dry_run_required: dec.iam.scim.dry_run_required,
          },
          idp_health: dec.iam.idp_health,
        },
        ai: { ranking: dec.ai.ranking },
      }),
      { headers: { "content-type": "application/json" } }
    );
  } catch (e) {
    return new Response(JSON.stringify({ error: String(e) }), { status: 500, headers: { "content-type": "application/json" } });
  }
});
