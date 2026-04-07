// deno-lint-ignore-file no-explicit-any
// Edge Function: profile-learn
// Computes lightweight behavioral features per (user_id, org_id) and upserts via RPC.
// Requires env: SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY
// Optional: CRON_SECRET for scheduled invocations

import { createClient } from "@supabase/supabase-js";

// Initialize Supabase service client (service role)
const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
if (!SUPABASE_URL || !SUPABASE_SERVICE_ROLE_KEY) {
  throw new Error("Missing SUPABASE_URL or SUPABASE_SERVICE_ROLE_KEY");
}
const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY, {
  auth: { persistSession: false },
});

// Lightweight feature computation over recent events
async function computeFeatures(userId: string, orgId: string) {
  // Consider last 90 days of events for more stable signals
  const since = new Date(Date.now() - 90 * 24 * 60 * 60 * 1000).toISOString();

  // Fetch relevant events and minimal columns
  const { data: events, error } = await supabase
    .from("behavior_events")
    .select("event_type, properties, ts, geo_deadhead_miles, toll_used, origin_tz")
    .eq("user_id", userId)
    .eq("org_id", orgId)
    .gte("ts", since);

  if (error) throw error;

  // Heuristics:
  // - max_deadhead_miles: 90th percentile of geo_deadhead_miles
  // - toll_aversion: 1 - share_of_toll_used_on_routes (0..1 where higher=more averse)
  // - preferred_corridors: top 3 normalized corridor IDs from properties.corridor_id
  // - pickup_window_local: densest 3-hour window across local pickup hours derived from ts + origin_tz or client-provided local hour
  let maxDeadhead: number | null = null;
  let tollAversion = 0.5;
  let preferredCorridors: string[] = [];
  let pickupWindow: { start: number; end: number } | null = null;

  const deadheads: number[] = [];
  let tollYes = 0;
  let tollNo = 0;
  const corridorCount = new Map<string, number>();
  const pickupHours: number[] = [];

  for (const ev of events ?? []) {
    // deadhead
    const dh = Number((ev as any).geo_deadhead_miles);
    if (Number.isFinite(dh) && dh >= 0) deadheads.push(dh);

    // toll
    const tollUsed = (ev as any).toll_used;
    if (typeof tollUsed === "boolean") {
      if (tollUsed) tollYes++; else tollNo++;
    } else if (tollUsed != null) {
      // tolerate 0/1 or "true"/"false"
      const v = String(tollUsed).toLowerCase();
      if (v === "true" || v === "1") tollYes++; else if (v === "false" || v === "0") tollNo++;
    }

    // corridor
    const props = (ev as any).properties;
    const corridorId = props?.corridor_id ?? props?.route_corridor ?? props?.lane_id;
    if (typeof corridorId === "string" && corridorId) {
      corridorCount.set(corridorId, (corridorCount.get(corridorId) || 0) + 1);
    }

    // pickup local hour
    // Prefer an explicit local hour if present in properties; else approximate using ts + origin_tz
    let hour: number | null = null;
    if (Number.isFinite(props?.pickup_local_hour)) {
      hour = Math.min(23, Math.max(0, Number(props.pickup_local_hour)));
    } else if ((ev as any).ts) {
      const dt = new Date((ev as any).ts as string);
      // If origin_tz is IANA zone not available in Deno runtime, fall back to UTC hour
      try {
        const tz = (ev as any).origin_tz || props?.origin_tz;
        if (typeof tz === "string" && tz) {
          // Use Intl API when available; may still fall back depending on Deno deploy
          const fmt = new Intl.DateTimeFormat("en-US", {
            timeZone: tz,
            hour: "2-digit",
            hour12: false,
          });
          // Extract hour from formatted parts robustly
          const parts = fmt.formatToParts(dt);
          const hStr = parts.find((p) => p.type === "hour")?.value;
          const parsed = hStr != null ? Number(hStr) : NaN;
          if (Number.isFinite(parsed)) hour = parsed;
        }
      } catch {
        /* ignore */
      }
      if (hour == null) hour = dt.getUTCHours(); // conservative fallback
    }
    if (hour != null && Number.isFinite(hour)) pickupHours.push(hour);
  }

  // max_deadhead_miles as 90th percentile
  if (deadheads.length > 0) {
    deadheads.sort((a, b) => a - b);
    const idx = Math.floor(0.9 * (deadheads.length - 1));
    maxDeadhead = Math.round(deadheads[idx]);
  }

  // toll_aversion: if many routes used tolls, aversion low; else high
  const totalTollObs = tollYes + tollNo;
  if (totalTollObs > 0) {
    const tollRate = tollYes / totalTollObs; // 0..1
    tollAversion = Math.max(0, Math.min(1, 1 - tollRate));
  }

  // preferred_corridors: top 3 by count
  if (corridorCount.size > 0) {
    preferredCorridors = [...corridorCount.entries()]
      .sort((a, b) => b[1] - a[1])
      .slice(0, 3)
      .map(([id]) => id);
  }

  // pickup_window_local: densest 3-hour band
  if (pickupHours.length > 0) {
    const buckets = new Map<number, number>();
    for (const h of pickupHours) buckets.set(h, (buckets.get(h) || 0) + 1);
    // Find densest 3-hour window
    let best = { score: -1, start: 0 };
    for (let h = 0; h < 24; h++) {
      const score =
        (buckets.get(h) || 0) +
        (buckets.get((h + 1) % 24) || 0) +
        (buckets.get((h + 2) % 24) || 0);
      if (score > best.score) best = { score, start: h };
    }
    pickupWindow = { start: best.start, end: (best.start + 2) % 24 };
  }

  const features = {
    max_deadhead_miles: maxDeadhead || null,
    toll_aversion: tollAversion,
    preferred_corridors: preferredCorridors,
    pickup_window_local: pickupWindow,
  } as const;

  // Confidence: simple heuristic based on events count
  const count = events?.length ?? 0;
  const confidence = Math.max(0.1, Math.min(1, count / 200));

  return { features, confidence };
}

async function listActiveUsers() {
  // Derive unique (user_id, org_id) pairs from behavior_events in the last 30 days
  const since = new Date(Date.now() - 30 * 24 * 60 * 60 * 1000).toISOString();
  const { data, error } = await supabase
    .from("behavior_events")
    .select("user_id, org_id")
    .gte("ts", since);

  if (error) throw error;

  const seen = new Set<string>();
  const pairs: { user_id: string; org_id: string }[] = [];
  for (const row of data ?? []) {
    const key = `${(row as any).user_id}:${(row as any).org_id}`;
    if (!seen.has(key)) {
      seen.add(key);
      pairs.push(row as any);
    }
  }
  return pairs;
}

Deno.serve(async (req) => {
  try {
    // Optional: protect cron
    const cronSecret = Deno.env.get("CRON_SECRET");
    if (cronSecret) {
      const hdr = req.headers.get("X-Cron-Secret");
      if (hdr !== cronSecret) return new Response("forbidden", { status: 403 });
    }

    const targets = await listActiveUsers();
    let updated = 0;

    // Process sequentially to keep load low; could batch/chunk if needed
    for (const t of targets) {
      try {
        const { features, confidence } = await computeFeatures(t.user_id, t.org_id);
        const { error: upErr } = await supabase.rpc("upsert_learned_profile", {
          p_user_id: t.user_id,
          p_org_id: t.org_id,
          p_features: features,
          p_confidence: confidence,
        });
        if (upErr) throw upErr;
        updated++;
      } catch (e) {
        console.error("compute/upsert error", t, e);
      }
    }

    return new Response(
      JSON.stringify({ ok: true, updated, targets: targets.length }),
      { headers: { "content-type": "application/json" } },
    );
  } catch (e) {
    console.error(e);
    return new Response(
      JSON.stringify({ ok: false, error: String(e) }),
      { status: 500, headers: { "content-type": "application/json" } },
    );
  }
});
