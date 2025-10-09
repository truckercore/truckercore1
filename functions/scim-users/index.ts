import { createClient } from "https://esm.sh/@supabase/supabase-js@2.46.1";
import { rateLimit } from "../scim/_rate.ts";
import { weakEtag, assertIfMatch } from "../scim/_etag.ts";
import { scimOk, scimErr, SCIM_CT } from "../scim/_scim_util.ts";

function bearerOK(req: Request) {
  const token = req.headers.get("authorization") || req.headers.get("Authorization") || "";
  const want = Deno.env.get("SCIM_BEARER_TOKEN");
  return !!(want && token.replace(/^Bearer\s+/i, "").trim() === want);
}

function keyForReq(req: Request) {
  const ip = req.headers.get("x-forwarded-for") || req.headers.get("cf-connecting-ip") || req.headers.get("x-real-ip") || "unknown";
  const tok = (req.headers.get("authorization") || '').slice(-8);
  return `${ip}:${tok}`;
}

function parseFilter(filter: string) {
  const m = filter.match(/^(userName|externalId)\s+eq\s+\"([^\"]+)\"/i);
  if (!m) return null;
  return { field: m[1], value: m[2] } as { field: "userName"|"externalId"; value: string };
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return scimOk({});
  if (!bearerOK(req)) return scimErr(401, "Unauthorized");
  await rateLimit(`scim:${keyForReq(req)}`, 60, 60);

  const svc = createClient(Deno.env.get("SUPABASE_URL")!, Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!, { auth: { persistSession: false }});

  try {
    const url = new URL(req.url);
    const org_id = url.searchParams.get("org_id");
    if (!org_id) return scimErr(400, "missing org_id");

    if (req.method === "GET") {
      const q = url.searchParams;
      const startIndex = Math.max(1, Number(q.get("startIndex") ?? 1));
      const count = Math.min(200, Math.max(1, Number(q.get("count") ?? 50)));
      const filter = q.get("filter") || "";
      let query = svc.from("scim_users").select("id,external_id,user_name,email,active,updated_at", { count: "exact" }).eq("org_id", org_id);
      const where = parseFilter(filter);
      if (where) {
        if (where.field === "userName") query = query.eq("user_name", where.value);
        if (where.field === "externalId") query = query.eq("external_id", where.value);
      }
      const { data, error, count: total } = await query.range(startIndex - 1, startIndex - 1 + count - 1);
      if (error) return scimErr(400, error.message);
      const Resources = (data || []).map((u) => ({ id: u.id, userName: u.user_name, externalId: u.external_id, active: u.active, emails: [{ value: u.email }], meta: { version: weakEtag(u.id, u.updated_at), lastModified: u.updated_at } }));
      return scimOk({ schemas:["urn:ietf:params:scim:api:messages:2.0:ListResponse"], Resources, totalResults: total ?? Resources.length, startIndex, itemsPerPage: count });
    }

    if (req.method === "POST") {
      const body = await req.json();
      const externalId = body.externalId || body.id || body.userName;
      if (externalId) {
        const { data: exists } = await svc.from("scim_users").select("id,external_id,user_name,email,active,updated_at").eq("org_id", org_id).eq("external_id", externalId).maybeSingle();
        if (exists) {
          const et = weakEtag(exists.id, exists.updated_at);
          return scimOk({ id: exists.id, userName: exists.user_name, externalId: exists.external_id, active: exists.active, emails: [{ value: exists.email }] }, 200);
        }
      }
      const user = {
        org_id,
        external_id: externalId,
        user_name: body.userName,
        email: body.emails?.[0]?.value || body.userName,
        given_name: body.name?.givenName ?? null,
        family_name: body.name?.familyName ?? null,
        active: body.active !== false,
        roles: body.roles ?? [],
        meta: body.meta ?? {},
      };
      const { data, error } = await svc.from("scim_users").insert(user).select("id,external_id,user_name,email,active,updated_at").single();
      await svc.from("identity_audit").insert({ org_id, kind: 'scim_create', actor: 'scim', subject: user.external_id, details: { path: 'Users', ok: !error } });
      if (error) return scimErr(400, error.message);
      const etag = weakEtag(data.id, data.updated_at);
      return scimOk({ id: data.id, userName: data.user_name, externalId: data.external_id, active: data.active, emails: [{ value: data.email }] }, 201);
    }

    if (req.method === "PUT" || req.method === "PATCH") {
      const id = url.pathname.split("/").pop();
      if (!id) return scimErr(400, "missing id");
      const { data: cur, error: getErr } = await svc.from("scim_users").select("id,updated_at").eq("id", id).maybeSingle();
      if (getErr || !cur) return scimErr(404, "not found");
      const et = weakEtag(cur.id, cur.updated_at);
      assertIfMatch(req, et);
      const body = await req.json().catch(()=>({}));
      let fields: Record<string, any> = {};
      if (req.method === "PUT") {
        fields = {
          user_name: body.userName,
          email: body.emails?.[0]?.value ?? null,
          given_name: body.name?.givenName ?? null,
          family_name: body.name?.familyName ?? null,
          active: body.active !== false,
        };
      } else {
        if (Array.isArray(body.Operations)) {
          for (const op of body.Operations) {
            const path = (op.path || '').toLowerCase();
            if (path.includes('active')) fields.active = Boolean(op.value?.active ?? op.value ?? false);
            if (path.includes('emails')) fields.email = op.value?.[0]?.value ?? fields.email;
            if (path.includes('name.givenname')) fields.given_name = op.value ?? fields.given_name;
            if (path.includes('name.familyname')) fields.family_name = op.value ?? fields.family_name;
          }
        } else if (typeof body.active === 'boolean') {
          fields.active = body.active;
        }
      }
      const { data: up, error } = await svc.from("scim_users").update(fields).eq("id", id).select("id,external_id,user_name,email,active,updated_at").single();
      await svc.from("identity_audit").insert({ org_id, kind: 'scim_update', actor: 'scim', subject: id, details: { path: 'Users', fields } });
      if (error) return scimErr(400, error.message);
      const newE = weakEtag(up.id, up.updated_at);
      return scimOk({ id: up.id, userName: up.user_name, externalId: up.external_id, active: up.active, emails: [{ value: up.email }] }, 200, { ETag: newE });
    }

    return scimErr(405, "method_not_allowed");
  } catch (e) {
    return scimErr(400, String((e as any)?.message ?? e));
  }
});