// Supabase Edge Function: config.fusion
// GET /functions/v1/config.fusion
// Returns current fusion/speed tile config with clamps and sane defaults for debugging.

import "jsr:@supabase/functions-js/edge-runtime";

function clamp(v: number, lo: number, hi: number) {
  if (!Number.isFinite(v)) return lo;
  return Math.max(lo, Math.min(hi, v));
}

Deno.serve((req) => {
  if (req.method !== "GET") {
    return new Response(JSON.stringify({ error: "method_not_allowed" }), { status: 405, headers: { "content-type": "application/json" } });
  }

  // Read with sane clamps and defaults
  const HALF_LIFE_MIN = clamp(Number(Deno.env.get("DECAY_HALFLIFE_MIN") ?? Deno.env.get("DECAY_HALF_LIFE_MIN") ?? 30), 5, 240);
  const WINDOW_MIN = clamp(Number(Deno.env.get("FUSION_WINDOW_MIN") ?? 45), 10, 240);
  const OPERATOR_WEIGHT = clamp(Number(Deno.env.get("OPERATOR_WEIGHT") ?? 1.0), 0, 2);
  const CROWD_MIN_TRUST = clamp(Number(Deno.env.get("CROWD_MIN_TRUST") ?? 0.2), 0, 1);
  const SPEED_WINDOW_MIN = clamp(Number(Deno.env.get("SPEED_WINDOW_MIN") ?? 15), 5, 120);
  const SPEED_TILE_ZOOM = clamp(Number(Deno.env.get("SPEED_TILE_ZOOM") ?? 12), 8, 16);

  const payload = {
    fusion: {
      decay_half_life_min: HALF_LIFE_MIN,
      window_min: WINDOW_MIN,
      operator_weight: OPERATOR_WEIGHT,
      crowd_min_trust: CROWD_MIN_TRUST,
    },
    speed_tiles: {
      window_min: SPEED_WINDOW_MIN,
      zoom: SPEED_TILE_ZOOM,
    },
  } as const;

  return new Response(JSON.stringify(payload), {
    headers: {
      "content-type": "application/json",
      "cache-control": "no-store",
    },
  });
});
