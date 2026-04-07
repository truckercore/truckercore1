// Supabase Edge Function (scheduled): cron.aggregate_poi_states
// Runs every 1–5 minutes to aggregate recent POI reports into parking_state and weigh_station_state.
// Uses a Dirichlet-style count with configurable decay to compute posterior and confidence.

import "jsr:@supabase/functions-js/edge-runtime";
import { createClient } from "npm:@supabase/supabase-js@2";
import { appendAudit } from "../_shared/audit.ts";

const URL = Deno.env.get("SUPABASE_URL")!;
const SERVICE = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;

// Config toggles (env-driven)
const ENV_DECAY_HALFLIFE_RAW = Number(Deno.env.get("DECAY_HALFLIFE_MIN") ?? Deno.env.get("DECAY_HALF_LIFE_MIN") ?? '');
const ENV_FUSION_WINDOW_MIN_RAW = Number(Deno.env.get("FUSION_WINDOW_MIN") ?? '');
const ENV_OPERATOR_WEIGHT_RAW = Number(Deno.env.get("OPERATOR_WEIGHT") ?? '');
const ENV_CROWD_MIN_TRUST_RAW = Number(Deno.env.get("CROWD_MIN_TRUST") ?? '');

function clamp(v: number, lo: number, hi: number, def: number){
  if (!Number.isFinite(v)) return def;
  return Math.max(lo, Math.min(hi, v));
}
let warnedOnce = false;

function softmaxArgmax(dist: Record<string, number>): { key: string; conf: number }{
  let total = 0; for (const v of Object.values(dist)) total += v;
  if (total <= 0) return { key: 'unknown', conf: 0.0 };
  let bestK = 'unknown'; let best = -1;
  for (const [k,v] of Object.entries(dist)) { const p = v/total; if (p > best){ best = p; bestK = k; } }
  return { key: bestK, conf: best };
}

function decayWeight(minutesOld: number, halfLifeMin: number){
  if (!Number.isFinite(minutesOld) || minutesOld <= 0) return 1;
  const lambda = Math.log(2) / Math.max(1, halfLifeMin);
  return Math.exp(-lambda * minutesOld);
}

async function getHalfLifeMin(admin: ReturnType<typeof createClient>): Promise<number> {
  // Order of precedence: table app_settings.decay_half_life_min -> env DECAY_HALFLIFE_MIN or DECAY_HALF_LIFE_MIN -> default 30
  try {
    const { data } = await admin.from('app_settings').select('key, value').eq('key', 'decay_half_life_min').maybeSingle();
    const v = (data as any)?.value;
    const n = Number(typeof v === 'object' ? v?.n ?? v?.value ?? v : v);
    if (Number.isFinite(n) && n > 0 && n < 24*60) return Math.floor(n);
  } catch {}
  const envN = Number.isFinite(ENV_DECAY_HALFLIFE_RAW) ? ENV_DECAY_HALFLIFE_RAW : Number.NaN;
  if (Number.isFinite(envN) && envN > 0 && envN < 24*60) return Math.floor(envN);
  return 30;
}

Deno.serve(async (_req) => {
  const started = Date.now();
  try {
    const admin = createClient(URL, SERVICE);
    const now = new Date();

    // Clamp envs with defaults
    const windowMin = clamp(ENV_FUSION_WINDOW_MIN_RAW, 10, 240, 120);
    const operatorWeight = clamp(ENV_OPERATOR_WEIGHT_RAW, 0, 2, 1.0);
    const crowdMinTrust = clamp(ENV_CROWD_MIN_TRUST_RAW, 0, 1, 0.2);

    if (!warnedOnce) {
      try {
        console.warn(JSON.stringify({
          event: 'fusion.config.warn',
          message: 'Using clamped fusion settings (defaults if unset)',
          window_min: windowMin,
          operator_weight: operatorWeight,
          crowd_min_trust: crowdMinTrust,
        }));
      } catch {}
      warnedOnce = true;
    }

    const sinceIso = new Date(Date.now() - windowMin * 60_000).toISOString();
    let halfLifeMin = await getHalfLifeMin(admin);
    // Enforce 5–240 clamp even if DB provided value is out of desired range
    halfLifeMin = clamp(halfLifeMin, 5, 240, 30);

    // Fetch recent reports bucketed by poi_id and kind
    const { data: reports, error } = await admin
      .from('poi_reports')
      .select('poi_id, kind, status, trust_snapshot, ts, payload')
      .gte('ts', sinceIso);
    if (error) return new Response(JSON.stringify({ error: error.message }), { status: 500, headers: { 'content-type':'application/json' } });

    const byPoi: Record<string, { parking: Array<any>; weigh: Array<any> }> = {};
    for (const r of (reports ?? []) as any[]){
      const pid = r.poi_id as string;
      if (!byPoi[pid]) byPoi[pid] = { parking: [], weigh: [] };
      if (r.kind === 'parking') byPoi[pid].parking.push(r);
      if (r.kind === 'weigh') byPoi[pid].weigh.push(r);
    }

    // Process parking
    const parkingWrites: any[] = [];
    for (const [poi_id, group] of Object.entries(byPoi)){
      if (group.parking.length){
        const alpha = { open: 0.1, some: 0.1, full: 0.1 } as Record<string, number>;
        const rawCounts = { open: 0, some: 0, full: 0 } as Record<string, number>;
        for (const r of group.parking){
          const trust = Math.max(0, Math.min(1, Number(r.trust_snapshot ?? 0.5)));
          const minutesOld = Math.max(0, (now.getTime() - new Date(r.ts).getTime()) / 60000);
          const wDecay = decayWeight(minutesOld, halfLifeMin);
          const isOperator = !!((r as any)?.payload && (r as any).payload.source === 'operator');
          const base = isOperator && operatorWeight > 0
            ? operatorWeight
            : Math.max(trust, crowdMinTrust);
          const w = base * wDecay;
          const s = String(r.status || '').toLowerCase();
          if (s === 'open' || s === 'some' || s === 'full') {
            alpha[s] += w;
            rawCounts[s] += 1;
          }
        }
        const { key, conf } = softmaxArgmax(alpha);
        parkingWrites.push({ poi_id, occupancy: key, confidence: Number(conf.toFixed(3)), last_update: now.toISOString(), source_mix: { user_reports: group.parking.length } });
        // Per-POI audit (compact reason payload)
        try {
          await appendAudit(admin, {
            action: 'state.aggregate.parking',
            entity: 'poi',
            entity_id: poi_id,
            diff: { half_life_min: halfLifeMin, counts: rawCounts, weights: alpha, chosen: key, confidence: Number(conf.toFixed(3)) }
          });
        } catch {}
      }
    }

    if (parkingWrites.length){
      await admin.from('parking_state').upsert(parkingWrites, { onConflict: 'poi_id' });
    }

    // Process weigh station
    const weighWrites: any[] = [];
    for (const [poi_id, group] of Object.entries(byPoi)){
      if (group.weigh.length){
        const alpha = { open: 0.1, closed: 0.1, bypass: 0.1 } as Record<string, number>;
        const rawCounts = { open: 0, closed: 0, bypass: 0 } as Record<string, number>;
        for (const r of group.weigh){
          const trust = Math.max(0, Math.min(1, Number(r.trust_snapshot ?? 0.5)));
          const minutesOld = Math.max(0, (now.getTime() - new Date(r.ts).getTime()) / 60000);
          const wDecay = decayWeight(minutesOld, halfLifeMin);
          const isOperator = !!((r as any)?.payload && (r as any).payload.source === 'operator');
          const base = isOperator && operatorWeight > 0
            ? operatorWeight
            : Math.max(trust, crowdMinTrust);
          const w = base * wDecay;
          const s = String(r.status || '').toLowerCase();
          if (s in alpha) { alpha[s] += w; rawCounts[s] += 1; }
        }
        const { key, conf } = softmaxArgmax(alpha);
        weighWrites.push({ poi_id, status: key, confidence: Number(conf.toFixed(3)), last_update: now.toISOString(), source_mix: { user_reports: group.weigh.length } });
        try {
          await appendAudit(admin, {
            action: 'state.aggregate.weigh',
            entity: 'poi',
            entity_id: poi_id,
            diff: { half_life_min: halfLifeMin, counts: rawCounts, weights: alpha, chosen: key, confidence: Number(conf.toFixed(3)) }
          });
        } catch {}
      }
    }

    if (weighWrites.length){
      await admin.from('weigh_station_state').upsert(weighWrites, { onConflict: 'poi_id' });
    }

    // Batch audit summary (best-effort)
    try {
      await appendAudit(admin, {
        action: 'state.aggregate',
        entity: 'poi_state',
        entity_id: 'batch',
        diff: { half_life_min: halfLifeMin, processed_poi: Object.keys(byPoi).length, parking_updates: parkingWrites.length, weigh_updates: weighWrites.length }
      });
    } catch {}

    const duration_ms = Date.now() - started;
    try { console.log(JSON.stringify({ event: 'fusion.run', window_min: windowMin, half_life_min: halfLifeMin, processed_poi: Object.keys(byPoi).length, parking_updates: parkingWrites.length, weigh_updates: weighWrites.length, duration_ms })); } catch {}

    return new Response(JSON.stringify({ ok: true, processed_poi: Object.keys(byPoi).length, parking_updates: parkingWrites.length, weigh_updates: weighWrites.length, duration_ms }), { headers: { 'content-type':'application/json' } });
  } catch (e) {
    return new Response(JSON.stringify({ error: String(e) }), { status: 500, headers: { 'content-type':'application/json' } });
  }
});
