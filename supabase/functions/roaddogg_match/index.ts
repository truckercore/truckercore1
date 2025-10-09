import 'jsr:@supabase/functions-js/edge-runtime';
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.45.4';

type MatchRow = {
  driver_id: string;
  hos_drive_min: number;
  hos_duty_min: number;
  safety: number;
  profit: number;         // 0..100
  detention_penalty: number; // 0..100 (higher is better, less detention)
  deadhead_score?: number;   // 0..100 (optional)
};

const sb = createClient(
  Deno.env.get('SUPABASE_URL')!,
  Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
);

async function getConfig() {
  const { data } = await sb
    .from('roaddogg_config')
    .select('*')
    .order('created_at', { ascending: false })
    .limit(1)
    .maybeSingle();
  return (
    data ?? {
      w_hos: 0.4,
      w_profit: 0.3,
      w_safety: 0.2,
      w_detention: 0.1,
      w_deadhead: 0.0,
      min_hos_drive_minutes: 120,
      confidence_gap: 5.0,
    }
  );
}

async function getLoad(load_id: string) {
  const { data, error } = await sb
    .from('loads')
    .select(
      'id, origin, destination, pickup_at, dropoff_at, revenue_cents, fuel_cents, tolls_cents, maintenance_cents, wage_cents'
    )
    .eq('id', load_id)
    .single();
  if (error) throw new Error(error.message);
  return data as any;
}

async function listDrivers(): Promise<{ id: string }[]> {
  const { data, error } = await sb.from('drivers').select('id').limit(1000);
  if (error) throw new Error(error.message);
  return (data ?? []) as any[];
}

async function hosMinutes(driver_id: string) {
  const { data, error } = await sb.rpc('hos_minutes_remaining', {
    p_driver: driver_id,
    p_tz: 'UTC',
  });
  if (error) throw new Error(error.message);
  const row = Array.isArray(data) ? data[0] : data;
  return {
    drive: Number(row?.drive_remaining_minutes ?? 0),
    duty: Number(row?.duty_remaining_minutes ?? 0),
  };
}

async function safetyScore(driver_id: string) {
  const { data } = await sb
    .from('safety_scores')
    .select('score')
    .eq('driver_id', driver_id)
    .maybeSingle();
  return Number((data as any)?.score ?? 100);
}

async function profitScore(load_id: string) {
  const { data } = await sb
    .from('load_financials')
    .select('profit_usd, revenue_usd, cost_usd')
    .eq('load_id', load_id)
    .maybeSingle();
  let profit = 0;
  if (data) {
    profit = Number((data as any).profit_usd ?? 0);
  } else {
    const l = await getLoad(load_id);
    const rev = Number(l.revenue_cents ?? 0) / 100.0;
    const cost =
      (Number(l.fuel_cents ?? 0) +
        Number(l.tolls_cents ?? 0) +
        Number(l.maintenance_cents ?? 0) +
        Number(l.wage_cents ?? 0)) /
      100.0;
    profit = rev - cost;
  }
  // Map profit to [0..100] using a soft cap: $0 -> ~10, $500+ -> 100
  const capped = Math.max(0, Math.min(100, profit / 5.0));
  return capped;
}

async function detentionPenalty(destination: string) {
  if (!destination) return 100;
  const { data } = await sb
    .from('v_detention_by_facility')
    .select('facility_name, avg_minutes')
    .eq('facility_name', destination)
    .maybeSingle();
  const avg = Number((data as any)?.avg_minutes ?? 0);
  // higher detention => lower score; 0m -> 100, 120m -> 0
  const score = Math.max(0, Math.min(100, 100 - (avg / 120) * 100));
  return score;
}

async function deadheadScore(/* driver_id: string, load: any */) {
  // Placeholder 100 until a geo cache is available
  return 100;
}

function combineScore(w: any, r: MatchRow) {
  const totalW = w.w_hos + w.w_profit + w.w_safety + w.w_detention + w.w_deadhead;
  const hosComponent = (Math.min(r.hos_drive_min, r.hos_duty_min) / 600) * 100; // 600 min => full score
  const s =
    w.w_hos * hosComponent +
    w.w_profit * r.profit +
    w.w_safety * r.safety +
    w.w_detention * r.detention_penalty +
    w.w_deadhead * (r.deadhead_score ?? 100);
  return Number(((s / (totalW || 1))).toFixed(2));
}

Deno.serve(async (req) => {
  try {
    if (req.method !== 'POST') {
      return new Response(JSON.stringify({ error: 'Use POST' }), { status: 405 });
    }
    const body = await req.json().catch(() => ({}));
    const load_id = body?.load_id as string | undefined;
    if (!load_id) {
      return new Response(JSON.stringify({ error: 'load_id required' }), { status: 400 });
    }

    const [cfg, load, drivers] = await Promise.all([
      getConfig(),
      getLoad(load_id),
      listDrivers(),
    ]);

    const results: Array<{ driver_id: string; score: number; rationale: string }> = [];

    for (const d of drivers) {
      const [hos, safety, profit, det, deadhead] = await Promise.all([
        hosMinutes(d.id),
        safetyScore(d.id),
        profitScore(load_id),
        detentionPenalty(load.destination ?? ''),
        deadheadScore(),
      ]);

      // Exclude by HOS hard rule
      if (hos.drive < Number(cfg.min_hos_drive_minutes ?? 120)) continue;

      const row: MatchRow = {
        driver_id: d.id,
        hos_drive_min: hos.drive,
        hos_duty_min: hos.duty,
        safety,
        profit,
        detention_penalty: det,
        deadhead_score: deadhead,
      };

      const score = combineScore(cfg, row);
      const rationale = [
        `HOS drive left: ${hos.drive}m, duty left: ${hos.duty}m`,
        `Safety score: ${safety.toFixed(0)}`,
        `Profit score: ${profit.toFixed(0)}`,
        `Detention score: ${det.toFixed(0)}`,
        `Pickup window: ${load.pickup_at ?? 'n/a'}`,
      ].join(' • ');

      results.push({ driver_id: d.id, score, rationale });
    }

    results.sort((a, b) => b.score - a.score);

    // Confidence heuristic
    let confidence: 'high' | 'medium' | 'low' = 'high';
    if (results.length >= 2 && Math.abs(results[0].score - results[1].score) < Number(cfg.confidence_gap ?? 5)) {
      confidence = 'medium';
    }

    // Persist scores to ai_match_scores (best-effort)
    if (results.length) {
      try {
        await sb.from('ai_match_scores').insert(
          results.map((r) => ({ load_id, driver_id: r.driver_id, score: r.score, rationale: r.rationale })),
          { returning: 'minimal' } as any
        );
      } catch (_) {
        // ignore insert failures
      }
    }

    return new Response(
      JSON.stringify({ load_id, confidence, matches: results.slice(0, 10) }),
      { status: 200, headers: { 'content-type': 'application/json' } }
    );
  } catch (e: any) {
    return new Response(
      JSON.stringify({ error: e?.message || 'roaddogg failed', matches: [] }),
      { status: 500, headers: { 'content-type': 'application/json' } }
    );
  }
});
