// Next.js App Router API: Generate + export ROI PDF
import crypto from "crypto";
import { NextRequest } from "next/server";

const SUPABASE_URL = process.env.NEXT_PUBLIC_SUPABASE_URL!;
const SERVICE_KEY = process.env.SUPABASE_SERVICE_ROLE_KEY!;
const STORAGE_BUCKET = process.env.EXPORTS_BUCKET || "exports";

function quarterStart(d = new Date()): string {
  const m = d.getUTCMonth();
  const q = Math.floor(m / 3);
  return new Date(Date.UTC(d.getUTCFullYear(), q * 3, 1)).toISOString().slice(0, 10);
}

function orgFromReq(req: NextRequest): string | undefined {
  const h = req.headers.get("x-app-org-id");
  return h || new URL(req.url).searchParams.get("org_id") || undefined;
}

export async function GET(req: NextRequest) {
  try {
    if (!SERVICE_KEY) return new Response("Service key missing", { status: 500 });

    const orgId = orgFromReq(req);
    if (!orgId) return new Response("org_id required", { status: 400 });

    const qStart = new URL(req.url).searchParams.get("quarter_start") || quarterStart();
    const CAP = Number(process.env.EXPORT_ROI_MONTHLY_CAP || 10);

    // Check usage (per org, per calendar month)
    {
      const now = new Date();
      const periodMonth = new Date(Date.UTC(now.getUTCFullYear(), now.getUTCMonth(), 1))
        .toISOString()
        .slice(0, 10);
      const url = new URL(`${SUPABASE_URL.replace(/\/$/, "")}/rest/v1/export_usage`);
      url.searchParams.set("org_id", `eq.${orgId}`);
      url.searchParams.set("period_month", `eq.${periodMonth}`);
      url.searchParams.set("kind", `eq.roi_pdf`);
      url.searchParams.set("select", "count");
      const u = await fetch(url, {
        headers: { apikey: SERVICE_KEY, Authorization: `Bearer ${SERVICE_KEY}` },
        cache: "no-store",
      });
      const arr: Array<{ count: number }> = await u.json().catch(() => []);
      const used = (arr?.[0]?.count as number) ?? 0;
      if (used >= CAP) {
        const h = new Headers();
        h.set("X-Export-Used", String(used));
        h.set("X-Export-Cap", String(CAP));
        return new Response("Monthly ROI report limit reached", { status: 402, headers: h });
      }
    }

    // Generate or fetch
    let reportId: string;
    {
      const rpc = `${SUPABASE_URL.replace(/\/$/, "")}/rest/v1/rpc/generate_roi_report`;
      const r = await fetch(rpc, {
        method: "POST",
        headers: {
          apikey: SERVICE_KEY,
          Authorization: `Bearer ${SERVICE_KEY}`,
          "Content-Type": "application/json",
          Prefer: "params=single-object",
        },
        body: JSON.stringify({ p_org: orgId, p_quarter_start: qStart }),
      });
      if (!r.ok) return new Response("Failed to generate report", { status: 500 });
      const txt = await r.text();
      reportId = txt.replace(/"/g, "");
    }

    // Fetch report row
    const url2 = new URL(`${SUPABASE_URL.replace(/\/$/, "")}/rest/v1/safety_roi_reports`);
    url2.searchParams.set("id", `eq.${reportId}`);
    url2.searchParams.set("select", "*");
    const r2 = await fetch(url2, {
      headers: { apikey: SERVICE_KEY, Authorization: `Bearer ${SERVICE_KEY}` },
      cache: "no-store",
    });
    const rows = await r2.json();
    if (!Array.isArray(rows) || !rows[0]) return new Response("Report not found", { status: 404 });
    const report = rows[0];

    // Minimal PDF placeholder (text buffer)
    const txt = `\nQuarterly Safety ROI Report\nOrg: ${orgId}\nQuarter: ${report.quarter_start} – ${report.quarter_end}\n\nBaseline (previous Q): ${report.baseline_total_alerts} alerts, ${report.baseline_urgent_alerts} urgent\nThis Quarter: ${report.period_total_alerts} alerts, ${report.period_urgent_alerts} urgent\nChange: ${report.delta_pct ?? "N/A"}%\n\nTop 5 Risk Corridors:\n${JSON.stringify(report.top_corridors, null, 2)}\n\nInsurance Note:\n${report.insurance_note || ""}\n`;
    const pdf = Buffer.from(txt);
    const sha256 = crypto.createHash("sha256").update(pdf).digest("hex");
    const filename = `roi_${orgId}_${qStart}.pdf`;
    const key = `${orgId}/${new Date().toISOString().slice(0, 10)}/${filename}`;

    // Upload to Storage
    {
      const sUrl = `${SUPABASE_URL.replace(/\/$/, "")}/storage/v1/object/${encodeURIComponent(STORAGE_BUCKET)}/${encodeURIComponent(key)}`;
      await fetch(sUrl, {
        method: "POST",
        headers: {
          apikey: SERVICE_KEY,
          Authorization: `Bearer ${SERVICE_KEY}`,
          "Content-Type": "application/pdf",
          "x-upsert": "true",
        },
        body: pdf,
      }).catch(() => {});
    }

    // Persist artifact record
    {
      const url3 = `${SUPABASE_URL.replace(/\/$/, "")}/rest/v1/export_artifacts`;
      await fetch(url3, {
        method: "POST",
        headers: {
          apikey: SERVICE_KEY,
          Authorization: `Bearer ${SERVICE_KEY}`,
          "Content-Type": "application/json",
          Prefer: "resolution=merge-duplicates",
        },
        body: JSON.stringify({
          org_id: orgId,
          kind: "roi_pdf",
          from_ts: report.quarter_start,
          to_ts: report.quarter_end,
          filename,
          content_type: "application/pdf",
          bytes: pdf.length,
          storage_path: `${STORAGE_BUCKET}/${key}`,
          sha256,
          signed: true,
        }),
      }).catch(() => {});
    }

    // Increment usage
    {
      const rpc2 = `${SUPABASE_URL.replace(/\/$/, "")}/rest/v1/rpc/increment_export_usage`;
      await fetch(rpc2, {
        method: "POST",
        headers: {
          apikey: SERVICE_KEY,
          Authorization: `Bearer ${SERVICE_KEY}`,
          "Content-Type": "application/json",
          Prefer: "params=single-object",
        },
        body: JSON.stringify({ p_org: orgId, p_kind: "roi_pdf" }),
      }).catch(() => {});
    }

    const headers = new Headers();
    headers.set("Content-Type", "application/pdf");
    headers.set("Content-Disposition", `attachment; filename="${filename}"`);
    headers.set("X-Artifact-SHA256", sha256);
    headers.set("Cache-Control", "no-store");
    return new Response(pdf, { status: 200, headers });
  } catch (e: any) {
    console.error(e);
    return new Response("Server error", { status: 500 });
  }
}
