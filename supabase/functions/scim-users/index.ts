import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

// Minimal SCIM Users stub: GET/POST/PATCH/DELETE
// Auth: Bearer token looked up in idp_configs.scim_bearer_token; derive org_id by matching token
// Logs: Insert into scim_provision_events for each op
// Actions: Call RPCs provision_user_for_org and set_user_active_state where appropriate

const URL = Deno.env.get("SUPABASE_URL")!;
const SERVICE = Deno.env.get("SUPABASE_SERVICE_ROLE") || Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");

if (!URL || !SERVICE) {
  console.error("Missing SUPABASE_URL or SUPABASE_SERVICE_ROLE");
}

const admin = createClient(URL, SERVICE!, { auth: { persistSession: false } });

async function resolveOrgByBearer(bearer?: string | null): Promise<{ org_id: string } | null> {
  if (!bearer) return null;
  const token = bearer.replace(/^Bearer\s+/i, "");
  const { data, error } = await admin
    .from("idp_configs")
    .select("org_id")
    .eq("scim_bearer_token", token)
    .eq("enabled", true)
    .limit(1)
    .maybeSingle();
  if (error) return null;
  return data as any;
}

function json(data: any, status = 200) {
  return new Response(JSON.stringify(data), { status, headers: { "content-type": "application/scim+json" } });
}

Deno.serve(async (req) => {
  try {
    const authz = req.headers.get("Authorization");
    const org = await resolveOrgByBearer(authz);
    if (!org) return json({ error: "unauthorized" }, 401);

    const url = new URL(req.url);
    const pathname = url.pathname;

    // Basic routing for /scim/v2/Users and /scim/v2/Users/:id
    if (!pathname.endsWith("/Users") && !/\/Users\//.test(pathname)) {
      return json({ error: "not_found" }, 404);
    }

    // LIST
    if (req.method === "GET" && pathname.endsWith("/Users")) {
      // Minimal: return empty list with count
      return json({ Resources: [], totalResults: 0, startIndex: 1, itemsPerPage: 0 });
    }

    // CREATE
    if (req.method === "POST" && pathname.endsWith("/Users")) {
      const body = await req.json().catch(() => ({} as any));
      const email = body?.userName || body?.emails?.[0]?.value || body?.email;
      if (!email) return json({ error: "missing userName/email" }, 400);
      // Provision using RPC
      const { data, error } = await admin.rpc("provision_user_for_org", { p_org_id: org.org_id, p_email: email });
      // Log event
      await admin.from("scim_provision_events").insert({ org_id: org.org_id, op: "provision", subject_type: "user", subject_id: email, email, raw: body, status: error ? "error" : "success", error: error?.message ?? null });
      if (error) return json({ error: error.message }, 500);
      // SCIM response
      return json({ id: data?.user_id ?? crypto.randomUUID(), userName: email, active: true }, 201);
    }

    // PATCH (activate/deactivate)
    if (req.method === "PATCH" && /\/Users\//.test(pathname)) {
      const userId = pathname.split("/Users/")[1];
      const body = await req.json().catch(() => ({} as any));
      // Expect Operations array with { op: "Replace", path: "active", value: boolean }
      const op = Array.isArray(body?.Operations) ? body.Operations.find((o: any) => String(o?.path ?? "").toLowerCase() === "active") : null;
      const active = op ? Boolean(op.value) : body?.active;
      if (typeof active !== "boolean") return json({ error: "missing active value" }, 400);
      const { error } = await admin.rpc("set_user_active_state", { p_user_id: userId, p_active: active });
      await admin.from("scim_provision_events").insert({ org_id: org.org_id, op: "update", subject_type: "user", subject_id: userId, raw: body, status: error ? "error" : "success", error: error?.message ?? null });
      if (error) return json({ error: error.message }, 500);
      return json({ id: userId, active });
    }

    // DELETE (deprovision)
    if (req.method === "DELETE" && /\/Users\//.test(pathname)) {
      const userId = pathname.split("/Users/")[1];
      // Mark inactive
      const { error } = await admin.rpc("set_user_active_state", { p_user_id: userId, p_active: false });
      await admin.from("scim_provision_events").insert({ org_id: org.org_id, op: "deprovision", subject_type: "user", subject_id: userId, status: error ? "error" : "success", error: error?.message ?? null });
      if (error) return json({ error: error.message }, 500);
      return new Response(null, { status: 204 });
    }

    // GET user by id (stub)
    if (req.method === "GET" && /\/Users\//.test(pathname)) {
      const userId = pathname.split("/Users/")[1];
      return json({ id: userId, userName: userId, active: true });
    }

    return json({ error: "unsupported" }, 405);
  } catch (e) {
    return json({ error: String(e) }, 500);
  }
});
