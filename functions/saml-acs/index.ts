import { createClient } from "https://esm.sh/@supabase/supabase-js@2.46.1";
import { verifySamlResponse } from "../_utils/saml_verify.ts";
import { seenAssertion } from "./acs/_replay.ts";
import { validTime } from "./acs/_time.ts";

const ok = (b: unknown, s=200, h:Record<string,string>={}) => new Response(JSON.stringify(b), { status: s, headers: { "content-type":"application/json", "access-control-allow-origin":"*", ...h }});

function isSafeRelay(u: string) {
  try { const x = new URL(u, "http://d/"); return !/^javascript:/i.test(u); } catch { return false; }
}

Deno.serve(async (req) => {
  if (req.method !== "POST") return ok({ error: "method" }, 405);
  try {
    const url = new URL(req.url);
    const orgId = url.searchParams.get("org_id");
    if (!orgId) return ok({ error: "missing_org" }, 400);

    const form = await req.formData();
    const samlResponse = String(form.get("SAMLResponse") ?? "");
    const relayState = String(form.get("RelayState") ?? "");
    if (!samlResponse) return ok({ error: "missing_saml" }, 400);
    const xml = atob(samlResponse);

    const svc = createClient(Deno.env.get("SUPABASE_URL")!, Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!);
    const { data: cfg } = await svc.from("saml_configs").select("*").eq("org_id", orgId).maybeSingle();
    if (!cfg || !cfg.enabled) return ok({ error: "saml_disabled" }, 403);

    const expected = { audience: String(cfg.sp_entity_id), acsUrl: (cfg.acs_urls as string[])[0] || url.toString(), clockSkewSec: Number(cfg.clock_skew_seconds ?? 120) };
    const idpCertPem = String(cfg.idp_cert_pem || "");
    const res = await verifySamlResponse(xml, idpCertPem, expected);
    if (!res.ok) {
      // Attempt to detect audience mismatch even if signature verification failed
      let status = 400;
      try {
        const dom2 = new DOMParser().parseFromString(xml, "text/xml");
        const aud = dom2?.querySelector("Audience")?.textContent?.trim();
        if (aud && String(aud) !== String(expected.audience)) status = 403;
      } catch {}
      await svc.from("identity_audit").insert({ org_id: orgId, kind: 'saml_assertion', actor: 'idp', details: { status: 'verify_fail', reason: res.reason } });
      return ok({ error: "verify_failed", reason: res.reason }, status);
    }

    // Parse minimal fields for replay + time checks and attributes
    const dom = new DOMParser().parseFromString(xml, "text/xml");
    const assertion = dom?.querySelector("Assertion");
    const assertionId = assertion?.getAttribute("ID") || assertion?.getAttribute("Id") || assertion?.getAttribute("id") || "";
    const cond = assertion?.querySelector("Conditions");
    const notBefore = cond?.getAttribute("NotBefore") || undefined;
    const notOnOrAfter = cond?.getAttribute("NotOnOrAfter") || undefined;

    if (!assertionId) return ok({ error: "missing_assertion_id" }, 422);
    if (await seenAssertion(assertionId)) return ok({ error: "replay" }, 409);
    if (!validTime(notBefore, notOnOrAfter, Number(cfg.clock_skew_seconds ?? 300))) return ok({ error: "expired" }, 400);

    // Extract attributes
    const attrs: Record<string, any> = {};
    dom?.querySelectorAll("Attribute").forEach((a) => {
      const name = a.getAttribute("Name") || a.getAttribute("FriendlyName") || "";
      const vals = Array.from(a.querySelectorAll("AttributeValue")).map(v=>v.textContent?.trim()).filter(Boolean);
      if (!name) return;
      attrs[name] = vals.length <= 1 ? vals[0] : vals;
    });
    const nameId = dom?.querySelector("NameID")?.textContent?.trim();

    const emailKey = (cfg.email_attr as string) || "Email";
    const email = (attrs[emailKey] as string) || nameId || "";
    if (!email) return ok({ error: "missing_email" }, 422);

    // Optional: roles via groups mapping (placeholder impl)
    const groupKey = (cfg.group_attr as string) || "Groups";
    const groups = Array.isArray(attrs[groupKey]) ? attrs[groupKey] : (attrs[groupKey]? [attrs[groupKey]] : []);

    await svc.from("identity_audit").insert({ org_id: orgId, kind: 'saml_assertion', actor: 'idp', subject: email.replace(/(^.).*(@.*$)/, "$1***$2"), details: { status: 'ok' } });

    const redirect = relayState && isSafeRelay(relayState) ? relayState : "/app";
    return new Response("", { status: 302, headers: { Location: redirect } });
  } catch (e) {
    return ok({ error: String((e as any)?.message ?? e) }, 400);
  }
});