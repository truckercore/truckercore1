// Supabase Edge Function: Analytics KPIs CSV Export
// Path: supabase/functions/analytics_kpis_export/index.ts
// Invoke with: GET /functions/v1/analytics_kpis_export?org_id=...&from=YYYY-MM-DD&to=YYYY-MM-DD

import "jsr:@supabase/functions-js/edge-runtime";
import { serve } from "https://deno.land/std@0.224.0/http/server.ts";
import { createClient } from "npm:@supabase/supabase-js@2";

serve(async (req) => {
  try {
    // Require a shared secret in header to prevent public access
    const secret = Deno.env.get("EXPORT_IFTA_SECRET");
    if (!secret || req.headers.get("x-export-secret") !== secret) {
      return new Response("Unauthorized", { status: 401 });
    }

    const u = new URL(req.url);
    const org_id = u.searchParams.get("org_id");
    const from = u.searchParams.get("from");
    const to = u.searchParams.get("to");
    if (!org_id || !from || !to) return new Response("bad_request", { status: 400 });

    const supa = createClient(
      Deno.env.get("SUPABASE_URL")!,
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
      { global: { headers: { Authorization: req.headers.get("Authorization") ?? "" } } },
    );

    const { data, error } = await supa
      .from("analytics_kpis")
      .select("org_id,period_start,metric,value")
      .eq("org_id", org_id)
      .gte("period_start", from)
      .lte("period_start", to)
      .order("period_start", { ascending: true });
    if (error) throw error;

    const rows = data ?? [];
    const headers = ["org_id", "period_start", "metric", "value"];

    // CSV injection mitigation: prefix risky cells with apostrophe
    function sanitize(val: unknown) {
      const s = String(val ?? "");
      return /^[=+\-@]/.test(s) ? `'${s}` : s;
    }

    const csv = [headers.join(",")] // header line
      .concat(
        rows.map((r: any) => [sanitize(r.org_id), sanitize(r.period_start), sanitize(r.metric), sanitize(r.value)].join(",")),
      )
      .join("\n");

    return new Response(csv, {
      status: 200,
      headers: {
        "Content-Type": "text/csv",
        "Content-Disposition": `attachment; filename="kpis_${from}_${to}.csv"`,
      },
    });
  } catch (e) {
    return new Response(JSON.stringify({ ok: false, error: String(e) }), { status: 500 });
  }
});
