import { createClient } from "https://esm.sh/@supabase/supabase-js@2.46.1";
import { rateLimit } from "../../../scim/_rate.ts";
import { scimOk as ok, scimErr as err } from "../../../scim/_scim_util.ts";

function bearerOK(req: Request) {
  const token = req.headers.get("authorization") || req.headers.get("Authorization") || "";
  const want = Deno.env.get("SCIM_BEARER_TOKEN");
  return want && token.replace(/^Bearer\s+/i, "").trim() === want;
}

function keyForReq(req: Request) {
  const ip = req.headers.get("x-forwarded-for") || req.headers.get("cf-connecting-ip") || req.headers.get("x-real-ip") || "unknown";
  const tok = (req.headers.get("authorization") || '').slice(-8);
  return `${ip}:${tok}`;
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return ok({});
  if (!bearerOK(req)) return err(401, "unauthorized");
  await rateLimit(`scim:${keyForReq(req)}`, 60, 60);

  const svc = createClient(Deno.env.get("SUPABASE_URL")!, Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!, { auth: { persistSession: false }});

  try {
    const url = new URL(req.url);
    const org_id = url.searchParams.get("org_id");
    if (!org_id) return err(400, "missing_org_id");

    if (req.method === "POST") {
      const body = await req.json();
      const grp = { org_id, external_id: body.id || body.externalId || body.displayName, display_name: body.displayName, meta: body.meta ?? {} };
      const { data, error } = await svc.from("scim_groups").insert(grp).select("id,external_id,display_name").single();
      await svc.from("identity_audit").insert({ org_id, kind: 'scim_group_op', actor: 'scim', subject: grp.external_id, details: { path: 'Groups', op: 'create', ok: !error } });
      if (error) return err(400, error.message);
      return ok({ id: data.id, displayName: data.display_name, externalId: data.external_id }, 201);
    }

    if (req.method === "PATCH") {
      const groupId = url.pathname.split("/").pop();
      if (!groupId) return err(400, "missing_group_id");
      const body = await req.json();
      // Azure sends Operations: add/remove members
      if (Array.isArray(body.Operations)) {
        for (const op of body.Operations) {
          const typ = (op.op || op.operation || '').toLowerCase();
          if (typ === 'add' && op.value?.members) {
            for (const m of op.value.members) {
              if (!m?.value) continue;
              await svc.from("scim_group_members").insert({ group_id: groupId, user_id: m.value }).onConflict("group_id,user_id").ignore();
            }
          } else if ((typ === 'remove') && typeof op.path === 'string') {
            const match = op.path.match(/members\[value eq \"([^\"]+)\"\]/i);
            if (match) {
              const uid = match[1];
              await svc.from("scim_group_members").delete().eq("group_id", groupId).eq("user_id", uid);
            }
          }
        }
      }
      await svc.from("identity_audit").insert({ org_id, kind: 'scim_group_op', actor: 'scim', subject: groupId, details: { path: 'Groups', op: 'patch' } });
      return ok({ id: groupId });
    }

    return err(405, "method_not_allowed");
  } catch (e) {
    return err(400, String((e as any)?.message ?? e));
  }
});
