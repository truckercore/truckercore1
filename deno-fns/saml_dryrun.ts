// deno-fns/saml_dryrun.ts
// Endpoint: /api/saml/dryrun (POST?org_id=...)
// Dry-run validate a pasted SAML Assertion XML: no session issuance; returns mapped user info.
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const URL = Deno.env.get("SUPABASE_URL")!;
const KEY = Deno.env.get("SUPABASE_SERVICE_ROLE")!;
const db = createClient(URL, KEY, { auth: { persistSession: false }});

async function loadConfig(orgId: string) {
  const { data, error } = await db.from("saml_configs").select("*, org_id").eq("org_id", orgId).maybeSingle();
  if (error || !data) throw new Error("cfg_not_found");
  return data as any;
}

async function groupRoleMap(orgId: string): Promise<Record<string, string[]>> {
  const { data, error } = await db.from("saml_group_role_map").select("idp_group, role").eq("org_id", orgId);
  if (error) return {};
  const map: Record<string, string[]> = {};
  for (const r of (data || []) as any[]) {
    map[r.idp_group] = map[r.idp_group] || [];
    map[r.idp_group].push(r.role);
  }
  return map;
}

function extract(xml: string, attr: string): string[] {
  const re = new RegExp(`<Attribute[^>]*Name=["']${attr}["'][^>]*>([\s\S]*?)<\\/Attribute>`, "i");
  const m = xml.match(re);
  if (!m) return [];
  const inner = m[1];
  const vals = Array.from(inner.matchAll(/<AttributeValue>([\s\S]*?)<\/AttributeValue>/gi)).map(v => (v[1] || '').trim());
  return vals.filter(Boolean);
}

function extractNameIdEmail(xml: string): string | null {
  const m = xml.match(/<saml:NameID[^>]*>([^<]+)<\/saml:NameID>/i) || xml.match(/<NameID[^>]*>([^<]+)<\/NameID>/i);
  if (!m) return null;
  const val = (m[1] || '').trim();
  return val || null;
}

Deno.serve(async (req) => {
  const orgId = new URL(req.url).searchParams.get("org_id");
  if (req.method !== "POST" || !orgId) return new Response("Bad Request", { status: 400 });
  const xml = await req.text();
  if (!xml.trim()) return new Response(JSON.stringify({ error: "empty_xml" }), { status: 400, headers: { "content-type": "application/json" } });

  try {
    const cfg = await loadConfig(orgId);
    const mapping = await groupRoleMap(orgId);

    // TODO: Implement signature/conditions validation. For now, minimal attribute extraction to aid mapping preview.
    const emailAttr = cfg.email_attr || "Email";
    const groupAttr = cfg.group_attr || "Groups";
    const nameAttr = cfg.name_attr || "Name";

    const emails = extract(xml, emailAttr);
    const groups = new Set(extract(xml, groupAttr));
    const names = extract(xml, nameAttr);
    const fallbackEmail = extractNameIdEmail(xml);

    const email = (emails[0] || fallbackEmail || "").toLowerCase();
    const name = names[0] || email || "";

    const roles = new Set<string>();
    for (const [grp, rs] of Object.entries(mapping)) {
      if (groups.has(grp)) rs.forEach(r => roles.add(r));
    }

    const mapped = { email, name, groups: Array.from(groups), roles: Array.from(roles), idp: cfg.idp_entity_id };
    return new Response(JSON.stringify({ ok: true, mapped }), { headers: { "content-type": "application/json" } });
  } catch (e) {
    return new Response(JSON.stringify({ ok: false, error: String((e as any)?.message || e) }), { status: 422, headers: { "content-type": "application/json" } });
  }
});
