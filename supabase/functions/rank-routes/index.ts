// deno-lint-ignore-file no-explicit-any
// Edge Function — rank-routes (optional)
// Similar structure to rank-loads: score route options and log context='routes'

import { createClient } from "https://esm.sh/@supabase/supabase-js@2.57.2";

type RouteOpt = {
  id?: string;
  origin_zip?: string | null;
  dest_zip?: string | null;
  deadhead_miles?: number | null;
  tolls?: boolean | null;
  pickup_time_local?: string | null; // ISO
  eta_minutes?: number | null;
  distance_mi?: number | null;
};

const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const SERVICE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
const supabase = createClient(SUPABASE_URL, SERVICE_KEY, { auth: { persistSession: false } });

function scoreRoute(opt: RouteOpt, features: any): number {
  let score = 0;

  // Deadhead
  const dh = Number(opt.deadhead_miles ?? 0);
  const maxDh = Number(features?.max_deadhead_miles ?? NaN);
  if (Number.isFinite(maxDh)) score += dh <= maxDh ? 5 : -Math.min(10, (dh - maxDh) * 0.4);
  else score -= dh * 0.2;

  // Tolls
  const tollAversion = typeof features?.toll_aversion === "number" ? features.toll_aversion : null;
  if (tollAversion !== null) {
    if (opt.tolls === false) score += 2.5 * tollAversion;
    if (opt.tolls === true) score += 2.5 * (1 - tollAversion);
  }

  // Pickup window
  const pickupWindow = features?.pickup_window_local as { start: number; end: number } | null;
  if (pickupWindow && opt.pickup_time_local) {
    const h = new Date(opt.pickup_time_local).getHours();
    const inBand =
      (pickupWindow.start <= pickupWindow.end && h >= pickupWindow.start && h <= pickupWindow.end) ||
      (pickupWindow.start > pickupWindow.end && (h >= pickupWindow.start || h <= pickupWindow.end));
    score += inBand ? 3.5 : -1.5;
  }

  // Distance/ETA heuristic (prefer shorter ETA and reasonable distance)
  const eta = Number(opt.eta_minutes ?? NaN);
  if (Number.isFinite(eta)) score += Math.max(-5, 5 - eta / 60); // mild preference to faster

  return score;
}

Deno.serve(async (req) => {
  try {
    const body = await req.json();
    const { user_id, org_id, candidates, limit = 25 } = body as {
      user_id: string;
      org_id: string;
      candidates: RouteOpt[];
      limit?: number;
    };

    if (!user_id || !org_id || !Array.isArray(candidates)) {
      return new Response(JSON.stringify({ ok: false, error: "invalid input" }), { status: 400 });
    }

    const { data: prof, error } = await supabase
      .from("merged_profile")
      .select("features_json")
      .eq("user_id", user_id)
      .eq("org_id", org_id)
      .maybeSingle();
    if (error) throw error;
    const features = prof?.features_json ?? {};

    const scored = (candidates || [])
      .map((c) => {
        const s = scoreRoute(c, features);
        const why: string[] = [];
        if (features?.max_deadhead_miles != null) {
          const over = Math.max(0, (c.deadhead_miles ?? 0) - features.max_deadhead_miles);
          if (over > 0) why.push(`deadhead +${Math.round(over)} over tolerance`);
        }
        if (features?.toll_aversion != null) why.push(c.tolls ? "tolls ok for you" : "avoids tolls (your pref)");
        if (features?.pickup_window_local && c.pickup_time_local) why.push("pickup fits your window");
        if (c.eta_minutes != null) why.push(`eta ${c.eta_minutes}m`);
        return { ...c, _score: s, _why: why };
      })
      .sort((a, b) => (b._score as number) - (a._score as number))
      .slice(0, Math.max(1, Math.min(limit, 100)));

    if (scored.length) {
      const rows = scored.map((it: any) => ({
        user_id,
        org_id,
        context: "routes",
        suggestion_json: it,
        features_snapshot: features,
        explanation: (it._why || []).slice(0, 3).join("; "),
        latency_ms: null,
      }));
      const { error: insErr } = await supabase.from("suggestions_log").insert(rows);
      if (insErr) console.error("suggestions_log insert error", insErr);
    }

    return new Response(JSON.stringify({ ok: true, items: scored }), {
      headers: { "content-type": "application/json" },
    });
  } catch (e: any) {
    console.error(e);
    return new Response(JSON.stringify({ ok: false, error: String(e?.message || e) }), { status: 500 });
  }
});