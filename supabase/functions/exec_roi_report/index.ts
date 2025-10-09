// functions/exec_roi_report/index.ts
// Purpose: Generate an executive ROI PDF (monthly) per org and distribute.
// Triggers: scheduled (monthly) or on-demand with org_id query.
// Env: SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY, STORAGE_BUCKET (e.g., 'exec-reports'),
//      REPORT_FROM_EMAIL, REPORT_S3_ENDPOINT/KEY/SECRET (optional), BRAND_NAME

import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import dayjs from "https://esm.sh/dayjs@1.11.11";
import { requireEntitlement } from "../_lib/entitlement.ts";

type KpiRow = {
  org_id: string;
  org_name: string | null;
  period_start: string;
  period_end: string;
  fuel_savings_usd: number;
  hos_savings_usd: number;
  promo_uplift_usd: number;
  anomalies_count: number;
  baseline_note: string | null;
};

const URL = Deno.env.get("SUPABASE_URL")!;
const KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
const STORAGE_BUCKET = Deno.env.get("STORAGE_BUCKET") ?? "exec-reports";
const BRAND = Deno.env.get("BRAND_NAME") ?? "TruckerCore";

const db = createClient(URL, KEY, { auth: { persistSession: false } });

// Replace with a real PDF renderer (e.g., Deno + puppeteer/pdf-lib). This is a JSON-to-PDF placeholder.
async function renderPdf(doc: any): Promise<Uint8Array> {
  // Minimal placeholder: produce a simple PDF-like buffer (replace in prod)
  const text = JSON.stringify(doc, null, 2);
  return new TextEncoder().encode(text);
}

async function fetchKpis(orgId: string | null, from: string, to: string): Promise<KpiRow[]> {
  // Prefer a materialized view or RPC that already rolls up ROI.
  // We provide a compatible view v_ai_roi_monthly in migrations.
  let q = db
    .from("v_ai_roi_monthly")
    .select("org_id, org_name, period, fuel_savings_usd, hos_savings_usd, promo_uplift_usd, anomalies_count, baseline_note")
    .gte("period", from)
    .lte("period", to);

  if (orgId) q = q.eq("org_id", orgId);
  const { data, error } = await q;
  if (error) throw error;

  return (data ?? []).map((r: any) => ({
    org_id: r.org_id,
    org_name: r.org_name ?? null,
    period_start: from,
    period_end: to,
    fuel_savings_usd: Number(r.fuel_savings_usd ?? 0),
    hos_savings_usd: Number(r.hos_savings_usd ?? 0),
    promo_uplift_usd: Number(r.promo_uplift_usd ?? 0),
    anomalies_count: Number(r.anomalies_count ?? 0),
    baseline_note: r.baseline_note ?? null,
  }));
}

function buildDoc(kpi: KpiRow) {
  const total = kpi.fuel_savings_usd + kpi.hos_savings_usd + kpi.promo_uplift_usd;
  return {
    brand: BRAND,
    title: "Executive ROI Summary",
    period: { start: kpi.period_start, end: kpi.period_end },
    org: { id: kpi.org_id, name: kpi.org_name },
    kpis: {
      fuel_savings_usd: kpi.fuel_savings_usd,
      hos_savings_usd: kpi.hos_savings_usd,
      promo_uplift_usd: kpi.promo_uplift_usd,
      total_roi_usd: total,
      anomalies_count: kpi.anomalies_count,
      baseline_note: kpi.baseline_note,
    },
    explainability: {
      coverage_target_pct: 98,
      coverage_actual_pct: null, // optionally join from an explainability view
      notes: "All ROI figures are derived from rolled-up daily signals with baselines."
    },
    appendix: {
      methods: [
        "Fuel savings derived from price competitiveness and redemption attribution windows.",
        "HOS savings based on prevented violations and idle reduction modeling.",
        "Promo uplift from funnel conversions tied to gallons sold within window.",
      ],
      baselines_used: kpi.baseline_note ?? "Default monthly baselines."
    },
    generated_at: new Date().toISOString()
  };
}

async function storeReport(orgId: string, ym: string, pdfBytes: Uint8Array) {
  const path = `${orgId}/exec-roi-${ym}.pdf`;
  const { error } = await db.storage.from(STORAGE_BUCKET).upload(path, pdfBytes, {
    contentType: "application/pdf",
    upsert: true,
  });
  if (error) throw error;
  const { data: pub } = db.storage.from(STORAGE_BUCKET).getPublicUrl(path);
  return { path, publicUrl: pub?.publicUrl ?? null };
}

async function recordSnapshot(orgId: string, ym: string, url: string | null, checksum: string | null) {
  await db.from("exec_reports").upsert({
    org_id: orgId,
    period_ym: ym,
    url,
    checksum,
    created_at: new Date().toISOString()
  }, { onConflict: "org_id,period_ym" });
}

async function distribute(orgId: string, link: string, periodLabel: string) {
  // Option A: email via your notification service
  // Option B: S3 drop via webhook / external job
  // This is a placeholder no-op; integrate as needed.
  console.log(`Distribute report: org=${orgId} link=${link} period=${periodLabel}`);
}

async function checksumSha256(data: Uint8Array): Promise<string> {
  try {
    const digest = await crypto.subtle.digest("SHA-256", data);
    return Array.from(new Uint8Array(digest)).map(b => b.toString(16).padStart(2, "0")).join("");
  } catch (_) {
    return "";
  }
}

Deno.serve(async (req) => {
  try {
    const url = new URL(req.url);
    const orgId = url.searchParams.get("org_id"); // optional: run for a single org
    const month = url.searchParams.get("month");  // yyyy-mm; default = previous month

    const firstDay = month ? dayjs(month + "-01") : dayjs().subtract(1, "month").startOf("month");
    const lastDay = firstDay.endOf("month");
    const periodStart = firstDay.format("YYYY-MM-DD");
    const periodEnd = lastDay.format("YYYY-MM-DD");
    const ym = firstDay.format("YYYY-MM");

    // Entitlement: require exec_analytics
    if (orgId) {
      const allowed = await requireEntitlement(orgId, "exec_analytics");
      if (!allowed) {
        return new Response(JSON.stringify({ error: "forbidden", feature: "exec_analytics", message: "Ask your admin to enable Executive Analytics in Entitlements." }), { status: 403, headers: { "content-type": "application/json" } });
      }
    }

    // 1) Fetch ROI KPIs
    const rows = await fetchKpis(orgId, periodStart, periodEnd);
    if (!rows.length) {
      return new Response(JSON.stringify({ ok: true, message: "No KPI rows for period" }), { headers: { "content-type": "application/json" } });
    }

    // If orgId not specified, filter rows to those entitled
    const filtered: KpiRow[] = [];
    if (!orgId) {
      for (const r of rows) {
        const ok = await requireEntitlement(r.org_id, "exec_analytics");
        if (ok) filtered.push(r);
      }
    } else {
      filtered.push(...rows);
    }

    if (!filtered.length) {
      return new Response(JSON.stringify({ ok: true, message: "No entitled orgs for period" }), { headers: { "content-type": "application/json" } });
    }

    // 2) For each org, render and store PDF
    const results: any[] = [];
    for (const r of filtered) {
      const doc = buildDoc(r);
      const pdf = await renderPdf(doc);
      const { path, publicUrl } = await storeReport(r.org_id, ym, pdf);
      const sum = await checksumSha256(pdf);
      await recordSnapshot(r.org_id, ym, publicUrl, sum);
      await distribute(r.org_id, publicUrl ?? path, `${periodStart}..${periodEnd}`);
      results.push({ org_id: r.org_id, url: publicUrl, path });
    }

    return new Response(JSON.stringify({ ok: true, period: { start: periodStart, end: periodEnd }, results }), {
      headers: { "content-type": "application/json" }
    });
  } catch (e) {
    return new Response(JSON.stringify({ ok: false, error: String(e?.message ?? e) }), {
      status: 500,
      headers: { "content-type": "application/json" }
    });
  }
});
