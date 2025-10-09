// supabase/functions/send-roi-emails/index.ts
// Scheduled Edge Function: send quarterly ROI emails
import { serve } from "https://deno.land/std@0.224.0/http/server.ts";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL") || Deno.env.get("NEXT_PUBLIC_SUPABASE_URL");
const SERVICE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
const SENDGRID_KEY = Deno.env.get("SENDGRID_API_KEY");
const FROM_EMAIL = Deno.env.get("FROM_EMAIL") || "reports@truckercore.com";

function quarterStart(d = new Date()): string {
  const m = d.getUTCMonth();
  const q = Math.floor(m / 3);
  return new Date(Date.UTC(d.getUTCFullYear(), q * 3, 1)).toISOString().slice(0, 10);
}

serve(async (req) => {
  try {
    if (!SUPABASE_URL || !SERVICE_KEY || !SENDGRID_KEY) return new Response("Config missing", { status: 500 });

    // Fetch all orgs with premium plan (filter by plan if available)
    const orgsResp = await fetch(`${SUPABASE_URL}/rest/v1/organizations?select=id,admin_email,plan&active=eq.true`, {
      headers: { apikey: SERVICE_KEY, Authorization: `Bearer ${SERVICE_KEY}` },
    });
    const allOrgs = await orgsResp.json().catch(() => []);
    const orgs = (allOrgs || []).filter((o: any) => ["tc_pro","tc_enterprise","pro","enterprise"].includes(String(o?.plan ?? "")));

    const qStart = new URL(req.url).searchParams.get("quarter_start") || quarterStart();
    const results: any[] = [];

    for (const org of orgs) {
      try {
        // Generate report
        const rpc = `${SUPABASE_URL}/rest/v1/rpc/generate_roi_report`;
        const r = await fetch(rpc, {
          method: "POST",
          headers: {
            apikey: SERVICE_KEY,
            Authorization: `Bearer ${SERVICE_KEY}`,
            "Content-Type": "application/json",
            Prefer: "params=single-object",
          },
          body: JSON.stringify({ p_org: org.id, p_quarter_start: qStart }),
        });
        if (!r.ok) throw new Error("RPC failed");

        // Fetch report
        const reportId = (await r.text()).replace(/"/g, "");
        const url2 = new URL(`${SUPABASE_URL}/rest/v1/safety_roi_reports`);
        url2.searchParams.set("id", `eq.${reportId}`);
        const r2 = await fetch(url2, { headers: { apikey: SERVICE_KEY, Authorization: `Bearer ${SERVICE_KEY}` } });
        const rows = await r2.json();
        if (!rows[0]) throw new Error("No report");
        const report = rows[0];

        // Send email via SendGrid
        const body = {
          personalizations: [{ to: [{ email: org.admin_email }] }],
          from: { email: FROM_EMAIL },
          subject: `Your Quarterly Safety ROI Report – ${qStart}`,
          content: [
            {
              type: "text/plain",
              value: `Hi,\n\nYour Q${Math.floor((new Date(qStart).getUTCMonth() / 3) + 1)} Safety ROI report is ready.\n\nAlerts: ${report.period_total_alerts} (${report.delta_pct ?? "N/A"}% vs last quarter)\nUrgent: ${report.period_urgent_alerts}\n\nDownload: ${SUPABASE_URL.replace("/rest/v1", "").replace(/\/$/, "")}/api/export-roi-report.pdf?org_id=${org.id}&quarter_start=${qStart}\n\nBest,\nTruckerCore Team`,
            },
          ],
        };
        const sg = await fetch("https://api.sendgrid.com/v3/mail/send", {
          method: "POST",
          headers: { Authorization: `Bearer ${SENDGRID_KEY}`, "Content-Type": "application/json" },
          body: JSON.stringify(body),
        });
        results.push({ org: org.id, status: sg.status });
      } catch (e: any) {
        results.push({ org: org.id, error: e?.message ?? String(e) });
      }
    }

    return new Response(JSON.stringify({ sent: results.length, results }), { status: 200, headers: { "content-type": "application/json" } });
  } catch (e) {
    return new Response(JSON.stringify({ error: String((e as any)?.message ?? e) }), { status: 500, headers: { "content-type": "application/json" } });
  }
});
