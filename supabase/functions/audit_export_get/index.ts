// Supabase Edge Function: audit_export_get
// Path: supabase/functions/audit_export_get/index.ts
// Invoke with: GET /functions/v1/audit_export_get?org_id=...&from=YYYY-MM-DD&to=YYYY-MM-DD
// Streams time-bounded audit export via RPC fn_audit_export.

import "jsr:@supabase/functions-js/edge-runtime";
import { serve } from "https://deno.land/std@0.224.0/http/server.ts";
import { createClient } from "npm:@supabase/supabase-js@2";

serve(async (req) => {
  try {
    const qs = new URL(req.url).searchParams;
    const org_id = qs.get("org_id");
    const from = qs.get("from");
    const to = qs.get("to");
    if (!org_id || !from || !to) return new Response("bad_request", { status: 400 });

    const supa = createClient(
      Deno.env.get("SUPABASE_URL")!,
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
    );

    const { data, error } = await supa.rpc("fn_audit_export", {
      p_org: org_id,
      p_from: from,
      p_to: to,
    });
    if (error) throw error;

    const body = (data ?? []).map((j: any) => JSON.stringify(j)).join("\n");
    return new Response(body, {
      status: 200,
      headers: {
        "Content-Type": "application/x-ndjson",
        "Content-Disposition": `attachment; filename="audit_${from}_${to}.ndjson"`,
      },
    });
  } catch (e) {
    return new Response(
      JSON.stringify({ ok: false, error: String(e) }),
      { status: 500 },
    );
  }
});
