// supabase/functions/ranker_v1/index.ts
// Minimal Edge Function for ranker_v1 (mock/heuristic v1)
// Note: This is a lightweight implementation to unblock integration.
// In production, replace heuristics with your loads finder + feature computation.

import { serve } from "https://deno.land/std@0.177.0/http/server.ts";

// Simple in-memory cache with TTL
const CACHE = new Map<string, { ts: number; value: unknown }>();
const TTL_MS = 60_000; // 60s

function normalizeKey(payload: Record<string, unknown>): string {
  const stable = JSON.stringify(payload, Object.keys(payload).sort());
  return btoa(stable);
}

// Weights v1 (can be moved to a table/config)
const WEIGHTS = {
  cph: 0.45,
  on_time_prob: 0.20,
  deadhead_penalty: 0.15,
  market_delta: 0.10,
  trust: 0.10,
};

serve(async (req: Request) => {
  try {
    if (req.method !== 'POST') {
      return new Response(JSON.stringify({ error: 'method_not_allowed' }), { status: 405 });
    }
    const input = await req.json();
    const query = input?.query ?? '';
    const filters = input?.filters ?? {};
    const profile = input?.profile ?? {};
    const orgId = input?.org_id ?? null;

    // Enforce hard constraints (equipment/min_cpm if provided)
    const equipment = filters.equipment ?? null;
    const minCpm = typeof filters.min_cpm === 'number' ? filters.min_cpm : null;

    const cacheKey = normalizeKey({ q: (query as string).trim().toLowerCase(), f: filters, p: profile, o: orgId });
    const now = Date.now();
    const cached = CACHE.get(cacheKey);
    if (cached && now - cached.ts < TTL_MS) {
      return new Response(JSON.stringify(cached.value), { headers: { 'Content-Type': 'application/json' } });
    }

    // TODO: Replace with real loads finder. For now, generate mock candidates.
    const baseCandidates = mockFindLoads({ query, filters, profile });

    const results = baseCandidates
      .filter((c) => (equipment ? c.equipment === equipment : true))
      .filter((c) => (typeof minCpm === 'number' ? c.cpm >= minCpm : true))
      .map((c) => computeFeaturesAndScore(c))
      .sort((a, b) => b.score - a.score)
      .slice(0, 50);

    const took = 5 + Math.floor(Math.random() * 10);

    const payload = {
      version: 'v1',
      personalized: Boolean(profile && Object.keys(profile).length),
      took_ms: took,
      suggestions: results.map((r) => ({
        id: r.id,
        candidate_id: r.candidate_id,
        cpm: r.cpm,
        miles: r.miles,
        cph_est: r.cph_est,
        market_cpm_delta: r.market_cpm_delta,
        deadhead_mi: r.deadhead_mi,
        broker_trust_score: r.broker_trust_score,
        sla_reply_minutes: r.sla_reply_minutes,
        confidence: r.confidence,
        top_reasons: r.top_reasons,
      })),
    };

    CACHE.set(cacheKey, { ts: now, value: payload });
    return new Response(JSON.stringify(payload), { headers: { 'Content-Type': 'application/json' } });
  } catch (e) {
    return new Response(JSON.stringify({ error: 'ranker_v1_failed', message: String(e) }), { status: 500 });
  }
});

// --- Mock domain helpers ---

type Candidate = {
  id: string;
  equipment: string;
  cpm: number; // $/mi
  miles: number;
  deadhead_mi: number;
  broker_trust_score: number; // 0..100
  market_cpm: number; // reference
  on_time_prob: number; // 0..1
  sla_reply_minutes?: number;
};

function mockFindLoads({ query, filters, profile }: { query: string; filters: any; profile: any }): Candidate[] {
  // Produce deterministic mock data from query hash
  const seed = (query + JSON.stringify(filters)).length;
  const equipments = ['van', 'reefer', 'flatbed'];
  const eq = filters.equipment && equipments.includes(String(filters.equipment)) ? String(filters.equipment) : equipments[seed % equipments.length];
  const items: Candidate[] = [];
  for (let i = 0; i < 30; i++) {
    const base = seed + i;
    const cpm = 1.5 + (base % 120) / 100; // 1.5..2.7
    const miles = 200 + (base % 800); // 200..1000
    const dead = (base % 120);
    const trust = 40 + (base % 60);
    const market = 1.4 + (base % 100) / 120; // 1.4..2.23
    const otp = 0.6 + ((base % 40) / 100); // 0.6..1.0
    const sla = (base % 4 === 0) ? 45 + (base % 30) : undefined;
    items.push({
      id: `mock-load-${base}`,
      equipment: eq,
      cpm,
      miles,
      deadhead_mi: dead,
      broker_trust_score: trust,
      market_cpm: market,
      on_time_prob: Math.min(1, otp),
      sla_reply_minutes: sla,
    });
  }
  return items;
}

function computeFeaturesAndScore(c: Candidate) {
  const cph_est = (c.cpm * c.miles) / Math.max(1, c.miles / 50); // assume avg 50 mph
  const market_cpm_delta = c.cpm - c.market_cpm;
  const deadheadPenalty = Math.min(1, c.deadhead_mi / 200); // scale 0..1
  const trust = c.broker_trust_score / 100;
  const onTime = c.on_time_prob;

  const score =
    WEIGHTS.cph * sigmoid(cph_est / 100) +
    WEIGHTS.on_time_prob * onTime +
    WEIGHTS.deadhead_penalty * (1 - deadheadPenalty) +
    WEIGHTS.market_delta * sigmoid(market_cpm_delta) +
    WEIGHTS.trust * trust;

  // Simple confidence blend based on data presence
  const confidence = 0.6 + 0.1 * (c.sla_reply_minutes ? 1 : 0);

  const reasons: string[] = [];
  if (market_cpm_delta > 0.15) reasons.push(`+${(market_cpm_delta * 100).toFixed(0)}% vs market`);
  if (c.deadhead_mi < 50) reasons.push(`${c.deadhead_mi.toFixed(0)} mi deadhead`);
  if (c.broker_trust_score >= 75) reasons.push(`Trust ${c.broker_trust_score}`);
  if (c.sla_reply_minutes) reasons.push(`Replies ~${c.sla_reply_minutes}m`);

  return {
    id: c.id,
    candidate_id: c.id,
    cpm: c.cpm,
    miles: c.miles,
    cph_est,
    market_cpm_delta,
    deadhead_mi: c.deadhead_mi,
    broker_trust_score: c.broker_trust_score,
    sla_reply_minutes: c.sla_reply_minutes,
    confidence,
    top_reasons: reasons.slice(0, 4),
    score,
  };
}

function sigmoid(x: number) {
  return 1 / (1 + Math.exp(-x));
}
