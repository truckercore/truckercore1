// Minimal SAML ACS stub. Replace with full validation.
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const URL = Deno.env.get("SUPABASE_URL")!;
const SERVICE = Deno.env.get("SUPABASE_SERVICE_ROLE") || Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
const db = createClient(URL, SERVICE!, { auth: { persistSession: false } });

function json(o: any, status = 200) { return new Response(JSON.stringify(o), { status, headers: { "content-type": "application/json" }}); }

Deno.serve(async (req) => {
  const u = new URL(req.url);
  if (!u.pathname.endsWith("/acs")) return new Response("Not Found", { status: 404 });
  try {
    // Capture POSTed SAMLResponse for audit (do not trust for auth in this stub)
    const body = await req.formData().catch(() => null);
    const samlResponse = body?.get("SAMLResponse");
    // Log system audit event (system kind)
    try {
      await db.from("system_audit_events").insert({ kind: 'system', target: 'saml.acs', severity: 1, detail: { len: typeof samlResponse === 'string' ? samlResponse.length : 0 } });
    } catch (_) {}
    return json({ ok: true, note: "SAML ACS stub received" });
  } catch (e) {
    return json({ error: String(e) }, 500);
  }
});
