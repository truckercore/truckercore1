// deno-fns/roi_export_nightly.ts
// Nightly job: export ROI rollups + baseline assumptions for each org with recent activity
// Writes PDFs to Storage and logs evidence via reports_exec_roi

import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const url = Deno.env.get("SUPABASE_URL")!;
const service = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
const funcUrl = Deno.env.get("FUNC_URL");
const db = createClient(url, service, { auth: { persistSession: false }});

Deno.serve(async () => {
  // find orgs with events in last 60 days (fallback: distinct orgs with entitlements)
  const since = new Date(Date.now() - 60 * 86400_000).toISOString();
  const { data: orgsByEvents, error } = await db
    .from("ai_roi_events")
    .select("org_id")
    .gte("created_at", since)
    .limit(1000);
  if (error) return new Response(JSON.stringify({ error: error.message }), { status: 500, headers: { "content-type": "application/json" } });

  const orgIds = Array.from(new Set((orgsByEvents ?? []).map((r: any) => r.org_id))).filter(Boolean);

  const endpoint = funcUrl ? `${funcUrl}/reports_exec_roi` : undefined;
  const results: any[] = [];

  for (const org_id of orgIds) {
    try {
      if (!endpoint) throw new Error("missing FUNC_URL");
      const resp = await fetch(endpoint, {
        method: "POST",
        headers: { "content-type": "application/json" },
        body: JSON.stringify({ org_id, range_days: 30, format: "pdf" }),
      });
      const json = await resp.json();
      results.push({ org_id, ok: resp.ok, ...json });
    } catch (e) {
      results.push({ org_id, ok: false, error: String(e) });
    }
  }

  return new Response(JSON.stringify({ ok: true, exported: results.length, results }), { headers: { "content-type": "application/json" } });
});
