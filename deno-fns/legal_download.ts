// deno-fns/legal_download.ts
// Endpoint: /api/legal/download?org_id=...&type=dpa|baa
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
const db = createClient(Deno.env.get("SUPABASE_URL")!, Deno.env.get("SUPABASE_SERVICE_ROLE")!, { auth: { persistSession: false }});

Deno.serve(async (req) => {
  try {
    const url = new URL(req.url);
    const orgId = url.searchParams.get("org_id");
    const type = url.searchParams.get("type"); // 'dpa'|'baa'
    if (!orgId || !type || !["dpa","baa"].includes(type)) return new Response("bad request", { status: 400 });

    const href = type === "dpa" ? (Deno.env.get("LEGAL_DPA_URL") || "") : (Deno.env.get("LEGAL_BAA_URL") || "");
    if (!href) return new Response("not configured", { status: 500 });

    // Audit download (service role insert)
    try {
      await db.from("legal_download_audit").insert({ org_id: orgId, doc_type: type, downloaded_at: new Date().toISOString() });
    } catch (_) { /* best-effort */ }

    return new Response(null, { status: 302, headers: { Location: href } });
  } catch (e) {
    return new Response(String((e as any)?.message || e), { status: 400 });
  }
});
