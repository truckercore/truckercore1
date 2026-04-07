// deno-lint-ignore-file no-explicit-any
// Edge Function — rank-loads (personalized re‑ranking)
// Env: SUPABASE_URL, SUPABASE_ANON_KEY (if verifying JWT) or SUPABASE_SERVICE_ROLE_KEY (server-only),
// but writes here are to suggestions_log which RLS allows for the user scope when using user's JWT.
// If you call this server-to-server, ensure inputs are validated and consider service role carefully.

import { createClient } from "https://esm.sh/@supabase/supabase-js@2.57.2";

type Load = {
  id?: string;
  origin_zip?: string | null;
  dest_zip?: string | null;
  deadhead_miles?: number | null;
  tolls?: boolean | null;
  pickup_time_local?: string | null; // ISO
  rpm?: number | null;
  broker_credit?: number | null; // 0..100
};

const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const SERVICE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY"); // optional if you plan to use service-side
const supabase = createClient(SUPABASE_URL, SERVICE_KEY ?? "", {
  auth: { persistSession: false },
});

function scoreLoad(load: Load, features: any): number {
  let score = 0;

  // 1) Deadhead tolerance
  const dh = Number(load.deadhead_miles ?? 0);
  const maxDh = Number(features?.max_deadhead_miles ?? NaN);
  if (Number.isFinite(maxDh)) {
    if (dh <= maxDh) {
      score += 6 - Math.min(5, (dh / Math.max(1, maxDh)) * 5);
    } else {
      score -= Math.min(10, (dh - maxDh) * 0.5);
    }
  } else {
    score -= dh * 0.2;
  }

  // 2) Corridor boost
  const corridors: string[] = Array.isArray(features?.preferred_corridors) ? features.preferred_corridors : [];
  const key = `${load.origin_zip ?? ""}->${load.dest_zip ?? ""}`;
  if (corridors.includes(key)) score += 10;

  // 3) Tolls preference
  const tollAversion = typeof features?.toll_aversion === "number" ? features.toll_aversion : null;
  if (tollAversion !== null) {
    if (load.tolls === false) score += 3 * tollAversion; // prefers no tolls
    if (load.tolls === true) score += 3 * (1 - tollAversion); // prefers tolls
  }

  // 4) Pickup window proximity (hour band)
  const pickupWindow = features?.pickup_window_local as { start: number; end: number } | null;
  if (pickupWindow && load.pickup_time_local) {
    const h = new Date(load.pickup_time_local).getHours();
    const inBand =
      (pickupWindow.start <= pickupWindow.end && h >= pickupWindow.start && h <= pickupWindow.end) ||
      (pickupWindow.start > pickupWindow.end && (h >= pickupWindow.start || h <= pickupWindow.end));
    if (inBand) score += 4;
    else score -= 2;
  }

  // 5) Business value
  score += (Number(load.rpm ?? 0) || 0) * 5; // prefer higher RPM
  const credit = Number(load.broker_credit ?? 50);
  if (Number.isFinite(credit)) score += (credit - 50) / 10; // center at 50

  return score;
}

Deno.serve(async (req) => {
  try {
    const body = await req.json();
    const { user_id, org_id, candidates, limit = 25 } = body as {
      user_id: string;
      org_id: string;
      candidates: Load[];
      limit?: number;
    };

    if (!user_id || !org_id || !Array.isArray(candidates)) {
      return new Response(JSON.stringify({ ok: false, error: "invalid input" }), { status: 400 });
    }

    // Load learned features
    const { data: prof, error } = await supabase
      .from("merged_profile")
      .select("features_json")
      .eq("user_id", user_id)
      .eq("org_id", org_id)
      .maybeSingle();
    if (error) throw error;
    const features = prof?.features_json ?? {};

    // Score + explain
    const scored = (candidates || [])
      .map((c) => {
        const s = scoreLoad(c, features);
        const why: string[] = [];
        if ((features?.preferred_corridors || []).includes(`${c.origin_zip ?? ""}->${c.dest_zip ?? ""}`))
          why.push("preferred corridor");
        if (features?.max_deadhead_miles != null) {
          const over = Math.max(0, (c.deadhead_miles ?? 0) - features.max_deadhead_miles);
          if (over > 0) why.push(`deadhead +${Math.round(over)} over tolerance`);
        }
        if (features?.toll_aversion != null) {
          why.push(c.tolls ? "tolls ok for you" : "avoids tolls (your pref)");
        }
        if (features?.pickup_window_local && c.pickup_time_local) why.push("pickup fits your window");
        if (c.rpm) why.push(`rpm ${c.rpm}`);
        if (c.broker_credit != null) why.push(`credit ${c.broker_credit}`);
        return { ...c, _score: s, _why: why };
      })
      .sort((a, b) => (b._score as number) - (a._score as number))
      .slice(0, Math.max(1, Math.min(limit, 100)));

    // Log suggestions (batched insert)
    if (scored.length) {
      const snapshot = features;
      const rows = scored.map((it: any) => ({
        user_id,
        org_id,
        context: "loads",
        suggestion_json: it,
        features_snapshot: snapshot,
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