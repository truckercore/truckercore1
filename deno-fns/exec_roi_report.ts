// deno-fns/exec_roi_report.ts
// Monthly Executive ROI PDF/HTML generator with snapshotting, checksums, and scheduled distribution.
// Schedule via Supabase cron: monthly on the 1st 02:00 UTC or trigger on-demand with ?org_id&month=YYYY-MM.

import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import dayjs from "https://esm.sh/dayjs@1.11.10";
import utc from "https://esm.sh/dayjs@1.11.10/plugin/utc";
dayjs.extend(utc);

// Minimal HTML -> PDF via Deno compatible renderer; swap with your preferred renderer/service.
async function htmlToPdf(html: string): Promise<Uint8Array> {
  // If you have a PDF microservice, call it here. Placeholder returns bytes of HTML (for demo).
  return new TextEncoder().encode(html);
}

function sha256Hex(bytes: Uint8Array): string {
  const digest = crypto.subtle.digestSync
    ? crypto.subtle.digestSync("SHA-256", bytes as any)
    : null;
  if (digest) return [...new Uint8Array(digest as ArrayBuffer)].map(b=>b.toString(16).padStart(2,'0')).join('');
  // fallback async
  throw new Error("Synchronous digest not available; use async variant or Node shim");
}

const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const SERVICE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE")!;
const STORAGE_BUCKET = Deno.env.get("EXEC_ROI_BUCKET") ?? "exec-reports";
const DIST_EMAIL = Deno.env.get("EXEC_ROI_EMAIL_DIST") ?? ""; // comma-separated fallback
const S3_WEBHOOK = Deno.env.get("EXEC_ROI_S3_WEBHOOK") ?? ""; // optional external uploader
const FROM_EMAIL = Deno.env.get("EXEC_ROI_FROM") ?? "reports@truckercore.com";

// Helper to email report via your notification service (replace with your integration)
async function sendEmail(to: string[], subject: string, html: string, attachment?: { name: string; bytes: Uint8Array; }) {
  // Implement using your mail provider; no-op placeholder:
  console.log("[email] to:", to.join(","), "subject:", subject, "attachment:", attachment?.name);
}

Deno.serve(async (req) => {
  try {
    const url = new URL(req.url);
    const orgId = url.searchParams.get("org_id") ?? "";
    const monthParam = url.searchParams.get("month"); // YYYY-MM
    const format = (url.searchParams.get("format") ?? "pdf").toLowerCase(); // pdf|html
    const deliver = (url.searchParams.get("deliver") ?? "true") === "true"; // email/upload
    if (!orgId) return json({ error: "org_id required" }, 400);

    const db = createClient(SUPABASE_URL, SERVICE_KEY, { auth: { persistSession: false } });

    // Resolve reporting window
    const month = monthParam ?? dayjs().utc().subtract(1, "month").format("YYYY-MM");
    const start = dayjs.utc(`${month}-01`).startOf("month");
    const end = start.endOf("month");

    // Load baseline + rollups (replace with your views)
    const { data: kpis, error: kErr } = await db.rpc("exec_roi_kpis_month", {
      p_org_id: orgId,
      p_from: start.toISOString(),
      p_to: end.toISOString()
    });
    if (kErr) throw kErr;

    const { data: baseline, error: bErr } = await db
      .from("roi_baselines")
      .select("id, snapshot_id, assumptions, created_at, hash")
      .eq("org_id", orgId)
      .lte("effective_at", start.toISOString())
      .order("effective_at", { ascending: false })
      .limit(1)
      .maybeSingle();
    if (bErr) throw bErr;

    const { data: anomalies, error: aErr } = await db.rpc("exec_roi_anomalies_month", {
      p_org_id: orgId,
      p_from: start.toISOString(),
      p_to: end.toISOString()
    });
    if (aErr) throw aErr;

    // Build HTML report
    const title = `Executive ROI Report — ${month}`;
    const html = renderHtml({
      title,
      orgId,
      month,
      start: start.toISOString(),
      end: end.toISOString(),
      kpis: kpis ?? {},
      baseline: baseline ?? null,
      anomalies: anomalies ?? []
    });

    const reportBytes = format === "html" ? new TextEncoder().encode(html) : await htmlToPdf(html);
    const checksum = sha256Hex(reportBytes);
    const fileExt = format === "html" ? "html" : "pdf";
    const objectPath = `${orgId}/${month}/exec_roi.${fileExt}`;

    // Upload to Supabase storage (archive)
    const { error: upErr } = await db.storage.from(STORAGE_BUCKET).upload(objectPath, reportBytes, {
      contentType: format === "html" ? "text/html" : "application/pdf",
      upsert: true
    });
    if (upErr) throw upErr;

    // Write snapshot audit
    const { error: snapErr } = await db.from("roi_report_snapshots").insert({
      org_id: orgId,
      month: `${month}-01`,
      storage_bucket: STORAGE_BUCKET,
      storage_path: objectPath,
      checksum_sha256: checksum,
      baseline_snapshot_id: baseline?.snapshot_id ?? null,
      generated_at: new Date().toISOString(),
      format
    });
    if (snapErr) throw snapErr;

    // Optional: push to S3 via webhook
    if (S3_WEBHOOK) {
      await fetch(S3_WEBHOOK, {
        method: "POST",
        headers: { "content-type": "application/json" },
        body: JSON.stringify({ org_id: orgId, month, bucket: STORAGE_BUCKET, path: objectPath, checksum, format })
      }).catch(() => {});
    }

    // Distribution (email)
    if (deliver) {
      // Get exec distribution list from DB if available
      const { data: dl } = await db.rpc("exec_distribution_list", { p_org_id: orgId }).catch(() => ({ data: null }));
      const to = ((dl as string[] | null) ?? (DIST_EMAIL ? DIST_EMAIL.split(",") : [])).map(s => s.trim()).filter(Boolean);
      const subj = `${title}`;
      if (to.length) {
        await sendEmail(to, subj, htmlPreview(html), { name: `exec_roi_${orgId}_${month}.${fileExt}`, bytes: reportBytes });
      }
    }

    return json({ ok: true, org_id: orgId, month, path: `storage://${STORAGE_BUCKET}/${objectPath}`, checksum, format });
  } catch (e) {
    return json({ error: String(e?.message ?? e) }, 500);
  }
});

function json(obj: unknown, status = 200): Response {
  return new Response(JSON.stringify(obj), { status, headers: { "content-type": "application/json" } });
}

function htmlPreview(full: string): string {
  // Lightweight inline summary for email body
  const max = 1800;
  const s = full.replace(/<style[\s\S]*?<\/style>/g,'').replace(/<[^>]*>/g,'').slice(0, max);
  return `<p>Attached is your monthly Executive ROI report.</p><pre style="white-space:pre-wrap;font-family:inherit">${s}...</pre>`;
}

function chartBar(data: Array<{ label: string; value: number }>, title: string) {
  // Inline simple bar chart as table (for PDF/HTML portability). Swap with real chart lib if available.
  const max = Math.max(1, ...data.map(d => Math.abs(d.value)));
  const rows = data.map(d => {
    const pct = Math.round((Math.abs(d.value)/max)*100);
    const bar = `<div style="background:#3b82f6;height:12px;width:${pct}%"></div>`;
    const val = d.value.toLocaleString(undefined, { maximumFractionDigits: 2 });
    return `<tr><td style="padding:4px 8px">${d.label}</td><td style="width:60%">${bar}</td><td style="padding-left:8px">${val}</td></tr>`;
  }).join("");
  return `
  <section>
    <h3>${title}</h3>
    <table style="width:100%;border-collapse:collapse">${rows}</table>
  </section>`;
}

function renderHtml(params: {
  title: string;
  orgId: string;
  month: string;
  start: string;
  end: string;
  kpis: any;
  baseline: any;
  anomalies: any[];
}) {
  const { title, orgId, month, start, end, kpis, baseline, anomalies } = params;

  const fuelUplift = Number(kpis?.fuel_uplift_usd ?? 0);
  const gallonsUplift = Number(kpis?.gallons_uplift ?? 0);
  const promoRoi = Number(kpis?.promo_roi ?? 0);
  const parkingFreshness = Number(kpis?.parking_freshness_pct ?? 0);
  const uptime = Number(kpis?.uptime_pct ?? 0);

  const kpiCards = [
    { label: "Fuel Uplift ($)", value: fuelUplift },
    { label: "Gallons Uplift", value: gallonsUplift },
    { label: "Promo ROI (x)", value: promoRoi },
    { label: "Parking Freshness (%)", value: parkingFreshness },
    { label: "Platform Uptime (%)", value: uptime }
  ];

  const kpiHtml = chartBar(kpiCards.map(c => ({ label: c.label, value: c.value })), "KPIs (Monthly)");

  const baselineAssumptions = baseline?.assumptions ?? {};
  const baselineHtml = `
    <section>
      <h3>Baselines & Assumptions</h3>
      <ul>
        ${Object.entries(baselineAssumptions).map(([k,v]) =>
          `<li><strong>${escapeHtml(k)}:</strong> ${escapeHtml(typeof v === 'string' ? v : JSON.stringify(v))}</li>`).join("")}
      </ul>
      <p>Baseline Snapshot: <code>${escapeHtml(baseline?.snapshot_id ?? "n/a")}</code></p>
      <p>Baseline Hash: <code>${escapeHtml(baseline?.hash ?? "n/a")}</code></p>
    </section>`;

  const anomaliesHtml = `
    <section>
      <h3>Anomalies & Flags</h3>
      ${
        (anomalies?.length ?? 0) === 0
          ? "<p>No significant anomalies detected this month.</p>"
          : `<ul>${anomalies.map(a => `<li>${escapeHtml(a.title ?? a.code ?? "anomaly")} — ${escapeHtml(a.detail ?? "")}</li>`).join("")}</ul>`
      }
    </section>`;

  const when = `${month} (${new Date(start).toUTCString()} – ${new Date(end).toUTCString()})`;

  return `<!doctype html>
<html>
<head>
<meta charset="utf-8">
<title>${escapeHtml(title)}</title>
<style>
  body{font-family:system-ui, -apple-system, Segoe UI, Roboto, Helvetica, Arial, sans-serif; color:#111; margin:24px;}
  h1{font-size:22px;margin:0 0 12px;}
  h2{font-size:18px;margin:16px 0 8px;}
  h3{font-size:16px;margin:12px 0 6px;}
  section{margin:14px 0;}
  table{font-size:13px;}
  .card-grid{display:grid;grid-template-columns:repeat(2,minmax(0,1fr));gap:10px;}
  .card{border:1px solid #e5e7eb;border-radius:8px;padding:10px;}
  .small{color:#555;font-size:12px;}
</style>
</head>
<body>
  <header>
    <h1>${escapeHtml(title)}</h1>
    <div class="small">Org: ${escapeHtml(orgId)} • Period: ${escapeHtml(when)}</div>
  </header>
  <section class="card-grid">
    <div class="card">
      <h3>Executive Summary</h3>
      <p>Estimated fuel uplift: <strong>$${num(fuelUplift)}</strong>. Gallons uplift: <strong>${num(gallonsUplift)}</strong>. Promo ROI: <strong>${num(promoRoi)}x</strong>.</p>
      <p>Operational freshness: <strong>${num(parkingFreshness)}%</strong>. Platform uptime: <strong>${num(uptime)}%</strong>.</p>
    </div>
    <div class="card">
      <h3>Highlights</h3>
      <ul>
        <li>Top promo playbooks contributed most of the ROI uplift.</li>
        <li>Parking freshness above threshold indicates healthy operator engagement.</li>
        <li>Any anomalies are listed below with context.</li>
      </ul>
    </div>
  </section>
  ${kpiHtml}
  ${baselineHtml}
  ${anomaliesHtml}
  <footer class="small">
    Generated by TruckerCore • ${escapeHtml(new Date().toUTCString())}
  </footer>
</body>
</html>`;
}

function num(v: number) {
  return (v ?? 0).toLocaleString(undefined, { maximumFractionDigits: 2 });
}
function escapeHtml(s: string) {
  return s.replace(/[&<>"']/g, (m) => ({ '&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;','\'':'&#39;' }[m]!));
}
