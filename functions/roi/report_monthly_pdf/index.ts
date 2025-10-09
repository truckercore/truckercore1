// deno-lint-ignore-file no-explicit-any
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.46.1";
import { PDFDocument, StandardFonts, rgb } from "https://deno.land/x/pdf_lib@1.4.0/mod.ts";

// Types for local use
type KPI = {
  day: string;
  fuel_cents: number;
  hos_cents: number;
  promo_cents: number;
  total_cents: number;
};

type Baseline = { key: string; value: number; snapshot_id: string };

type Spike = { day: string; multiple: number; amt_today: number };

const CORS = {
  "access-control-allow-origin": "*",
  "access-control-allow-headers": "content-type,authorization,x-idempotency-key",
  "access-control-allow-methods": "POST,OPTIONS",
};

const ok = (b: unknown, s = 200) =>
  new Response(JSON.stringify(b), {
    status: s,
    headers: { ...CORS, "content-type": "application/json" },
  });

async function sha256Hex(data: Uint8Array) {
  const hash = new Uint8Array(await crypto.subtle.digest("SHA-256", data));
  return Array.from(hash).map((b) => b.toString(16).padStart(2, "0")).join("");
}

async function entitlement(sb: any, org_id: string, key: string) {
  const { data } = await sb.rpc("entitlements_check", { p_org: org_id, p_feature: key });
  return data === true;
}

function dollars(cents?: number) {
  return `$${(((cents ?? 0) / 100).toFixed(2))}`;
}

function wrapText(line: string, max: number) {
  const words = line.split(" ");
  const lines: string[] = [];
  let cur = "";
  for (const w of words) {
    if ((cur + " " + w).trim().length > max) {
      lines.push(cur.trim());
      cur = w;
    } else {
      cur = (cur + " " + w).trim();
    }
  }
  if (cur) lines.push(cur);
  return lines;
}

async function renderPdf(params: {
  orgName: string;
  orgId: string;
  monthLabel: string; // "YYYY-MM"
  kpis: KPI[];
  baselines: Baseline[];
  anomalies: Spike[];
  explainabilityRate?: number;
}) {
  const pdf = await PDFDocument.create();
  const page = pdf.addPage([612, 792]); // Letter
  const font = await pdf.embedFont(StandardFonts.Helvetica);
  const bold = await pdf.embedFont(StandardFonts.HelveticaBold);

  let y = 750;
  const title = `Executive ROI Report — ${params.monthLabel}`;
  page.drawText(title, { x: 36, y, size: 18, font: bold, color: rgb(0.1, 0.1, 0.1) });
  y -= 26;
  page.drawText(`Organization: ${params.orgName} (${params.orgId})`, { x: 36, y, size: 10, font });
  y -= 18;

  // Summary (30-day totals)
  const sum = params.kpis.reduce(
    (acc, r) => {
      acc.fuel += r.fuel_cents || 0;
      acc.hos += r.hos_cents || 0;
      acc.promo += r.promo_cents || 0;
      acc.total += r.total_cents || 0;
      return acc;
    },
    { fuel: 0, hos: 0, promo: 0, total: 0 },
  );

  page.drawText("Summary (last 30 days)", { x: 36, y, size: 12, font: bold }); y -= 16;
  page.drawText(`Fuel savings:   ${dollars(sum.fuel)}`, { x: 36, y, size: 11, font }); y -= 12;
  page.drawText(`HOS avoidance:  ${dollars(sum.hos)}`, { x: 36, y, size: 11, font }); y -= 12;
  page.drawText(`Promo uplift:   ${dollars(sum.promo)}`, { x: 36, y, size: 11, font }); y -= 12;
  page.drawText(`Total ROI:      ${dollars(sum.total)}`, { x: 36, y, size: 11, font }); y -= 18;

  if (params.explainabilityRate !== undefined) {
    page.drawText(`Explainability coverage: ${(params.explainabilityRate * 100).toFixed(1)}%`, { x: 36, y, size: 10, font });
    y -= 14;
  }

  // Baselines
  page.drawText("Baselines & Assumptions", { x: 36, y, size: 12, font: bold }); y -= 16;
  for (const b of params.baselines) {
    const line = `• ${b.key}: ${b.value} (snapshot: ${b.snapshot_id.slice(0, 8)}…)`;
    const rows = wrapText(line, 90);
    for (const r of rows) { page.drawText(r, { x: 36, y, size: 10, font }); y -= 12; }
  }
  y -= 8;

  // Anomalies
  if (params.anomalies.length) {
    page.drawText("Anomalies detected", { x: 36, y, size: 12, font: bold, color: rgb(0.7, 0.1, 0.1) }); y -= 16;
    params.anomalies.slice(0, 6).forEach(a => {
      const txt = `• ${a.day}: ROI ${a.multiple.toFixed(1)}× 7-day median (${dollars(a.amt_today)})`;
      page.drawText(txt, { x: 36, y, size: 10, font, color: rgb(0.6, 0.1, 0.1) }); y -= 12;
    });
    y -= 8;
  }

  // Daily table
  page.drawText("Daily ROI", { x: 36, y, size: 12, font: bold }); y -= 16;
  const header = ["Day", "Fuel", "HOS", "Promo", "Total"];
  const cols = [36, 120, 200, 280, 360];
  header.forEach((h, i) => page.drawText(h, { x: cols[i], y, size: 10, font: bold })); y -= 12;

  for (const r of params.kpis.slice(0, 26)) {
    const cells = [r.day.slice(0, 10), dollars(r.fuel_cents), dollars(r.hos_cents), dollars(r.promo_cents), dollars(r.total_cents)];
    cells.forEach((c, i) => page.drawText(c, { x: cols[i], y, size: 10, font }));
    y -= 12; if (y < 60) break;
  }

  // Footer
  const ts = new Date().toISOString();
  page.drawText(`Generated: ${ts}`, { x: 36, y: 36, size: 9, font, color: rgb(0.4, 0.4, 0.4) });

  const bytes = await pdf.save();
  return new Uint8Array(bytes);
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("", { headers: CORS });
  if (req.method !== "POST") return ok({ error: "method" }, 405);

  const body = await req.json().catch(() => ({}));
  const { org_id, org_name, month = new Date().toISOString().slice(0, 7), force = false } = body;

  if (!org_id || !org_name) return ok({ error: "missing org_id/org_name" }, 422);

  const sb = createClient(Deno.env.get("SUPABASE_URL")!, Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!);

  // Entitlement gate
  if (!(await entitlement(sb, org_id, "exec_analytics"))) {
    return ok({ error: "forbidden", feature: "exec_analytics" }, 403);
  }

  // Per-org monthly quota (best-effort, local cache based)
  const monthKey = String(month);
  const qKey = `quota:${org_id}:${monthKey}`;
  const qMax = Number(Deno.env.get("EXEC_REPORT_MONTHLY_QUOTA") ?? "50");
  const qHit = await caches.default.match(new Request(qKey));
  const used = qHit ? Number((await qHit.json()).c) : 0;
  if (used >= qMax) {
    return new Response(JSON.stringify({ error: "quota_exceeded", used, quota: qMax }), {
      status: 429,
      headers: { ...CORS, "content-type": "application/json", "cache-control": "no-store" }
    });
  }

  // Idempotency (by month+org) unless force
  const idemKey = `roi:${org_id}:${month}`;
  const cacheHit = !force && await caches.default.match(new Request(idemKey));
  if (cacheHit) return ok(await cacheHit.json());

  // p95 timing sample start
  const t0 = performance.now();

  // Refresh & fetch KPIs
  await sb.rpc("ai_roi_rollup_refresh");
  const { data: rows } = await sb.from("ai_roi_rollup_day")
    .select("*").eq("org_id", org_id).order("day", { ascending: false }).limit(30);

  const kpis: KPI[] = (rows || []).map((r: any) => ({
    day: r.day,
    fuel_cents: r.fuel_cents || 0,
    hos_cents: r.hos_cents || 0,
    promo_cents: r.promo_cents || 0,
    total_cents: r.total_cents || 0,
  }));

  const { data: baselines } = await sb
    .from("v_ai_roi_baseline_effective")
    .select("key,value,snapshot_id")
    .eq("org_id", org_id);

  const { data: spikes } = await sb
    .from("v_ai_roi_spike_alerts")
    .select("org_id, amt_today, med_7d, multiple, computed_at")
    .eq("org_id", org_id);

  const explainabilityRate = undefined;

  // Render PDF
  const pdfBytes = await renderPdf({
    orgName: org_name,
    orgId: org_id,
    monthLabel: month,
    kpis,
    baselines: (baselines || []).map((b: any) => ({ key: b.key, value: Number(b.value), snapshot_id: b.snapshot_id })),
    anomalies: (spikes || []).map((s: any) => ({ day: new Date(s.computed_at).toISOString().slice(0,10), multiple: Number(s.multiple), amt_today: Number(s.amt_today) })),
    explainabilityRate,
  });

  // Hash + upload to Storage (bucket: REPORTS_BUCKET or default)
  const checksum = await sha256Hex(pdfBytes);
  const reportsBucket = Deno.env.get("REPORTS_BUCKET") || "exec-reports";
  const path = `roi/${org_id}/${month}/exec-roi-${month}.pdf`;

  // Use Supabase Storage client for portability
  const { error: upErr } = await sb.storage.from(reportsBucket).upload(path, pdfBytes, {
    contentType: "application/pdf",
    upsert: true,
  });
  if (upErr) return ok({ error: "upload_failed", detail: upErr.message }, 502);

  // Snapshot row in existing roi_exports registry
  const reportId = crypto.randomUUID();
  await sb.from("roi_exports").insert({
    org_id,
    period_month: `${month}-01`,
    report_id: reportId,
    storage_url: `${reportsBucket}/${path}`,
    hash_sha256: checksum,
  });

  // Signed URL
  const { data: signed } = await sb.storage.from(reportsBucket).createSignedUrl(path, 60 * 60 * 24 * 7);
  const tMs = Math.round(performance.now() - t0);
  console.log(JSON.stringify({ mod: "roi", ev: "exec_report_timing_ms", org_id, ms: tMs, ts: new Date().toISOString() }));
  const resp = { ok: true, path, checksum, signed_url: signed?.signedUrl ?? null };

  // Increment quota (best-effort)
  try {
    await caches.default.put(new Request(qKey), new Response(JSON.stringify({ c: used + 1 }), { headers: { "content-type": "application/json" } }));
  } catch (_) {}

  if (!force) await caches.default.put(new Request(idemKey), new Response(JSON.stringify(resp), { headers: { "content-type": "application/json" } }));

  return new Response(JSON.stringify(resp), {
    status: 200,
    headers: { ...CORS, "content-type": "application/json", "cache-control": "private, max-age=600", "x-exec-report-ms": String(tMs) }
  });
});