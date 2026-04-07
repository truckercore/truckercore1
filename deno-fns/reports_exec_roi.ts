// deno-fns/reports_exec_roi.ts
// POST body: { org_id: string, range_days?: number, format?: 'pdf'|'html' }
// Requires: SERVICE role and access to Supabase Storage (or S3 via gateway).

import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const SERVICE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
const STORAGE_BUCKET = Deno.env.get("REPORTS_BUCKET") ?? "exec-reports";
const ORIGIN = Deno.env.get("APP_ORIGIN") ?? "https://app.example.com";

// Placeholder HTML → PDF converter. Replace with real renderer (Puppeteer/Playwright/API).
async function htmlToPdfBytes(html: string): Promise<Uint8Array> {
  return new TextEncoder().encode(html);
}

async function sha256Hex(bytes: Uint8Array): Promise<string> {
  const buf = await crypto.subtle.digest("SHA-256", bytes);
  return Array.from(new Uint8Array(buf)).map(b => b.toString(16).padStart(2, "0")).join("");
}

Deno.serve(async (req) => {
  if (req.method !== "POST") {
    return new Response(JSON.stringify({ error: "method_not_allowed" }), { status: 405, headers: { "content-type": "application/json" } });
  }

  const db = createClient(SUPABASE_URL, SERVICE_KEY, { auth: { persistSession: false } });
  let body: any;
  try { body = await req.json(); } catch { return new Response(JSON.stringify({ error: "invalid_json" }), { status: 400, headers: { "content-type": "application/json" } }); }

  const org_id = body?.org_id as string | undefined;
  const range_days = Math.max(1, Math.min(90, Number(body?.range_days ?? 30)));
  const format = (body?.format ?? "pdf") as "pdf" | "html";
  if (!org_id) return new Response(JSON.stringify({ error: "missing_org_id" }), { status: 400, headers: { "content-type": "application/json" } });

  // Entitlement: exec_analytics required
  const { data: ent } = await db.rpc("get_entitlement", { p_org_id: org_id, p_feature_key: "exec_analytics" });
  const enabled = Array.isArray(ent) ? (ent[0]?.enabled === true) : (ent?.enabled === true || ent === true);
  if (!enabled) return new Response(JSON.stringify({ error: "forbidden", feature: "exec_analytics" }), { status: 403, headers: { "content-type": "application/json" } });

  const sinceIso = new Date(Date.now() - range_days * 86400_000).toISOString();

  // Data sources (reuse existing views if available; otherwise fallback to rollup + baselines)
  const [rollupRes, baseRes, explainRes, anomalyRes] = await Promise.all([
    db.from("ai_roi_rollup_day").select("day,fuel_cents,hos_cents,promo_cents").eq("org_id", org_id).gte("day", sinceIso).order("day", { ascending: true }),
    db.from("ai_roi_baselines").select("snapshot_id,key,value,effective_at").eq("org_id", org_id).order("effective_at", { ascending: false }).limit(5),
    db.from("ai_metrics").select("value").eq("model_key", "opa").eq("metric", "opa_explain_rate").gte("ts", new Date(Date.now() - 30 * 86400_000).toISOString()).limit(1000),
    db.from("v_ai_roi_spike_alerts").select("*").eq("org_id", org_id)
  ]);

  if (rollupRes.error) return new Response(JSON.stringify({ error: rollupRes.error.message }), { status: 500, headers: { "content-type": "application/json" } });
  if (baseRes.error) return new Response(JSON.stringify({ error: baseRes.error.message }), { status: 500, headers: { "content-type": "application/json" } });
  if (explainRes.error) return new Response(JSON.stringify({ error: explainRes.error.message }), { status: 500, headers: { "content-type": "application/json" } });
  if (anomalyRes.error) return new Response(JSON.stringify({ error: anomalyRes.error.message }), { status: 500, headers: { "content-type": "application/json" } });

  const rollups = rollupRes.data ?? [];
  const baselines = baseRes.data ?? [];
  const explainVals = (explainRes.data ?? []).map((r: any) => Number(r.value)).filter((v: any) => !isNaN(v));
  const explainRate = explainVals.length ? (explainVals.reduce((a: number, b: number) => a + b, 0) / explainVals.length) : 0;
  const anomalyCount = (anomalyRes.data ?? []).length;

  const sumUsd = (cents: number | null | undefined) => ((cents || 0) / 100);
  const today = new Date().toISOString().slice(0, 10);
  const baselineIds = baselines.map((b: any) => b.snapshot_id as string).filter(Boolean);

  const totals = rollups.reduce((acc: any, r: any) => {
    acc.fuel += sumUsd(r.fuel_cents);
    acc.hos += sumUsd(r.hos_cents);
    acc.promo += sumUsd(r.promo_cents);
    return acc;
  }, { fuel: 0, hos: 0, promo: 0 });

  const html = `<!doctype html>
<html><head><meta charset="utf-8"><title>Executive ROI Report — ${today}</title>
<style>body{font-family:Arial,sans-serif;color:#222}h1{margin:0 0 4px 0}.muted{color:#666;font-size:12px}.kpis{display:flex;gap:16px;margin:16px 0}.kpi{padding:12px;border:1px solid #eee;border-radius:6px;min-width:160px}table{width:100%;border-collapse:collapse;margin-top:12px}th,td{border-bottom:1px solid #eee;padding:6px 8px;text-align:left}.badge{display:inline-block;padding:2px 6px;border-radius:4px;font-size:12px}.ok{background:#e6f7e6;color:#196619}.warn{background:#fff7e6;color:#a86200}.crit{background:#ffe6e6;color:#a60000}</style>
</head>
<body>
  <h1>Executive ROI Report</h1>
  <div class="muted">Org: ${org_id} • Range: Last ${range_days} days • Generated: ${today}</div>
  <div class="kpis">
    <div class="kpi"><div class="muted">Fuel Savings (est)</div><div><b>$${totals.fuel.toLocaleString(undefined,{maximumFractionDigits:2})}</b></div></div>
    <div class="kpi"><div class="muted">HOS Savings (est)</div><div><b>$${totals.hos.toLocaleString(undefined,{maximumFractionDigits:2})}</b></div></div>
    <div class="kpi"><div class="muted">Promo Uplift</div><div><b>$${totals.promo.toLocaleString(undefined,{maximumFractionDigits:2})}</b></div></div>
    <div class="kpi"><div class="muted">Explainability</div><div><b>${Math.round(explainRate * 100)}%</b></div></div>
    <div class="kpi"><div class="muted">Anomalies</div><div><span class="badge ${anomalyCount===0?'ok':(anomalyCount<3?'warn':'crit')}">${anomalyCount}</span></div></div>
  </div>
  <h3>Baselines</h3>
  <div class="muted">Snapshot IDs: ${baselineIds.join(", ") || "—"}</div>
  <h3>Daily ROI (last ${range_days} days)</h3>
  <table><thead><tr><th>Day</th><th>Fuel $</th><th>HOS $</th><th>Promo $</th><th>Total $</th></tr></thead>
    <tbody>
      ${rollups.map((r: any) => {
        const f = sumUsd(r.fuel_cents); const h = sumUsd(r.hos_cents); const p = sumUsd(r.promo_cents); const t = f+h+p;
        const day = (r.day ? String(r.day).slice(0,10) : '');
        return `<tr><td>${day}</td><td>$${f.toFixed(2)}</td><td>$${h.toFixed(2)}</td><td>$${p.toFixed(2)}</td><td><b>$${t.toFixed(2)}</b></td></tr>`;
      }).join("")}
    </tbody>
  </table>
  <h3>Notes</h3>
  <ul>
    <li>Attribution method: PSM_v0</li>
    <li>Explainability: ${Math.round(explainRate*100)}% of AI outputs contained rationale.</li>
    <li>Anomaly status: ${anomalyCount===0?'None':'See anomalies view'}</li>
  </ul>
  <h3>Privacy</h3>
  <p class="muted">This report includes only aggregated ROI data for the selected period. Baseline snapshot IDs referenced: ${baselineIds.join(", ") || '—'}. Rationale presence rate (explainability): ${Math.round(explainRate*100)}%.</p>
  <div class="muted">Report generated by TruckerCore • ${ORIGIN}</div>
</body></html>`;

  if (format === "html") return new Response(html, { headers: { "content-type": "text/html" } });

  const pdfBytes = await htmlToPdfBytes(html);
  const hashHex = await sha256Hex(pdfBytes);
  const yyyymm = today.slice(0, 7);
  const reportId = crypto.randomUUID();
  const objectKey = `roi_exports/${org_id}/${yyyymm}/${reportId}.pdf`;

  // Upload to Storage
  const { error: upErr } = await db.storage.from(STORAGE_BUCKET).upload(objectKey, pdfBytes, {
    contentType: "application/pdf",
    upsert: true,
  });
  if (upErr) return new Response(JSON.stringify({ error: upErr.message }), { status: 500, headers: { "content-type": "application/json" } });

  // Insert registry rows
  await db.from("roi_exports").insert({
    org_id,
    period_month: `${yyyymm}-01`,
    report_id: reportId,
    storage_url: `${STORAGE_BUCKET}/${objectKey}`,
    hash_sha256: hashHex,
  });

  await db.from("compliance_evidence").insert({
    org_id,
    artifact: `${STORAGE_BUCKET}/${objectKey}`,
    hash_sha256: hashHex,
    source: "exec_roi_report",
  });

  const { data: signed, error: urlErr } = await db.storage.from(STORAGE_BUCKET).createSignedUrl(objectKey, 60 * 60 * 24 * 7);
  if (urlErr) return new Response(JSON.stringify({ error: urlErr.message }), { status: 500, headers: { "content-type": "application/json" } });

  return new Response(JSON.stringify({
    url: signed.signedUrl,
    key: objectKey,
    hash_sha256: hashHex,
    baselines: baselineIds,
    range_days
  }), { headers: { "content-type": "application/json" } });
});
