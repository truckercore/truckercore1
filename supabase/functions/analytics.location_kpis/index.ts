// Supabase Edge Function: analytics.location_kpis
// GET /functions/v1/analytics.location_kpis?location_id=uuid&period=30d
// Returns period KPIs for a location (fuel gallons/revenue, promo redemptions, parking utilization, review score)

import "jsr:@supabase/functions-js/edge-runtime";
import { createClient } from "npm:@supabase/supabase-js@2";

const URL = Deno.env.get("SUPABASE_URL")!;
const ANON = Deno.env.get("SUPABASE_ANON") ?? Deno.env.get("SUPABASE_ANON_KEY");
if (!ANON) throw new Error("Missing SUPABASE_ANON (fallback SUPABASE_ANON_KEY not set)");
if (!Deno.env.get("SUPABASE_ANON") && Deno.env.get("SUPABASE_ANON_KEY")) {
  console.warn("[deprecation] SUPABASE_ANON_KEY is deprecated in Edge Functions; please set SUPABASE_ANON instead");
}
const SERVICE = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;

function parsePeriod(q: string | null): { fromIso: string; toIso: string }{
  const to = new Date();
  let days = 30;
  if (q){
    const m = /^([0-9]{1,3})d$/i.exec(q.trim());
    if (m) days = Math.max(1, Math.min(365, Number(m[1])));
  }
  const from = new Date(to.getTime() - days * 24 * 60 * 60 * 1000);
  return { fromIso: from.toISOString(), toIso: to.toISOString() };
}

Deno.serve(async (req) => {
  try {
    if (req.method !== "GET") return new Response(JSON.stringify({ error: "METHOD_NOT_ALLOWED" }), { status: 405, headers: { "content-type": "application/json" } });
    const qs = new URL(req.url).searchParams;
    const location_id = qs.get("location_id");
    const period = qs.get("period"); // e.g., 7d, 30d, 90d
    if (!location_id) return new Response(JSON.stringify({ error: "MISSING_LOCATION_ID" }), { status: 400, headers: { "content-type": "application/json" } });

    const { fromIso, toIso } = parsePeriod(period);

    // Auth header is optional; service role client used for aggregate reads
    const user = createClient(URL, ANON, { global: { headers: { Authorization: req.headers.get("Authorization") ?? "" } } });
    const admin = createClient(URL, SERVICE);

    // Ensure location exists (and optionally return org_id)
    const { data: loc, error: lerr } = await admin.from("locations").select("location_id, org_id").eq("location_id", location_id).maybeSingle();
    if (lerr || !loc) return new Response(JSON.stringify({ error: "LOCATION_NOT_FOUND" }), { status: 404, headers: { "content-type": "application/json" } });

    // Fuel KPIs: attempt to read from a materialized view or table if present; otherwise zeros
    // Try common sources in this repo: station_fuel_sales (hypothetical), fuel_sales_daily
    let fuelGallons = 0;
    let fuelRevenueCents = 0;
    try {
      const { data: fs } = await admin
        .from("fuel_sales_daily")
        .select("gallons, revenue_cents")
        .eq("location_id", location_id)
        .gte("date", fromIso)
        .lte("date", toIso);
      if (Array.isArray(fs)){
        for (const r of fs as any[]){
          fuelGallons += Number(r.gallons || 0);
          fuelRevenueCents += Number(r.revenue_cents || 0);
        }
      }
    } catch {}

    // Promo redemptions within window
    let promoRedemptions = 0;
    let promoDiscountCents = 0;
    try {
      const { data: prs } = await admin
        .from("promo_redemptions")
        .select("discount_cents")
        .eq("location_id", location_id)
        .gte("created_at", fromIso)
        .lte("created_at", toIso)
        .eq("status", "approved");
      if (Array.isArray(prs)){
        promoRedemptions = prs.length;
        for (const r of prs as any[]) promoDiscountCents += Number(r.discount_cents || 0);
      }
    } catch {}

    // Parking utilization: try stop_scores.factors.parking averaged
    let parkingUtilization = null as number | null;
    try {
      const { data: sc } = await admin
        .from("stop_scores")
        .select("factors")
        .eq("location_id", location_id)
        .gte("created_at", fromIso)
        .lte("created_at", toIso);
      if (Array.isArray(sc) && sc.length){
        let sum = 0, n = 0;
        for (const r of sc as any[]){
          const p = typeof r?.factors?.parking === 'number' ? r.factors.parking : null;
          if (p != null){ sum += p; n++; }
        }
        if (n > 0) parkingUtilization = Math.max(0, Math.min(1, sum / n));
      }
    } catch {}

    // Review score: try stop_reviews aggregate if present
    let reviewScore = null as number | null;
    try {
      const { data: rs } = await admin
        .from("stop_reviews")
        .select("rating")
        .eq("location_id", location_id)
        .gte("created_at", fromIso)
        .lte("created_at", toIso);
      if (Array.isArray(rs) && rs.length){
        let sum = 0;
        for (const r of rs as any[]) sum += Number(r.rating || 0);
        reviewScore = Math.max(0, Math.min(5, sum / rs.length));
      }
    } catch {}

    const resp = {
      ok: true,
      location_id,
      period: { from: fromIso, to: toIso },
      fuel: { gallons: Math.round(fuelGallons * 100) / 100, revenue_cents: Math.round(fuelRevenueCents) },
      promos: { redemptions: promoRedemptions, discount_cents: promoDiscountCents },
      parking: { utilization: parkingUtilization },
      reviews: { avg_score: reviewScore },
    };

    return new Response(JSON.stringify(resp), { headers: { "content-type": "application/json" } });
  } catch (e) {
    return new Response(JSON.stringify({ error: String(e) }), { status: 500, headers: { "content-type": "application/json" } });
  }
});
