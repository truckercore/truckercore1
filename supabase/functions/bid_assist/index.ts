import 'jsr:@supabase/functions-js/edge-runtime';
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.45.4';

type Req = { origin:string; destination:string; equipment:string; pickup_at:string; driver_id?:string };

type Out = {
  lane: string;
  equipment: string;
  target_band: { p50: number|null; p80: number|null; confidence: number|null; sample: number|null; source?: string };
  adjustments: { deadhead: number; hos_ok: boolean; eta_ok: boolean; service_penalty: number };
  suggested_bid: number|null;
  sla_window_minutes: number;
  rationale: string[];
};

const sb = createClient(Deno.env.get('SUPABASE_URL')!, Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!);

Deno.serve(async (req) => {
  try {
    const body = (await req.json()) as Req;
    const lane = `${body.origin} → ${body.destination}`;
    // 1) pull recent daily rates for lane/equipment
    const { data: rates } = await sb
      .from('market_rates_daily')
      .select('date,p50,p80,source,sample_size,confidence')
      .eq('lane', lane)
      .eq('equipment', body.equipment)
      .order('date', { ascending: false })
      .limit(7);

    const base = rates?.[0];
    const p50 = Number(base?.p50 ?? 0);
    const p80 = Number(base?.p80 ?? 0);
    const conf = Number(base?.confidence ?? 0);
    const sample = Number(base?.sample_size ?? 0);

    // 2) simple adjustments (deadhead/service/hos)
    const pickupTs = new Date(body.pickup_at).getTime();
    const soon = (pickupTs - Date.now()) / 3600000; // hours ahead
    const servicePenalty = soon < 6 ? 50 : 0;

    let hosOk = true; const etaOk = true;
    if (body.driver_id) {
      const hos = await sb.rpc('hos_minutes_remaining', { p_driver: body.driver_id, p_tz: 'UTC' });
      const driveMin = Array.isArray(hos.data) ? (hos.data[0]?.drive_remaining_minutes ?? 0) : 0;
      hosOk = driveMin >= 120;
    }

    // 3) suggest inside [p50..p80] +/- penalties
    const baseTarget = Math.max(p50, Math.min(p80, p50 + (p80 - p50) * 0.25));
    const suggested = Math.max(0, baseTarget + servicePenalty);

    const out: Out = {
      lane,
      equipment: body.equipment,
      target_band: { p50: p50 || null, p80: p80 || null, confidence: conf || null, sample: sample || null, source: (base as any)?.source ?? undefined },
      adjustments: { deadhead: 0, hos_ok: hosOk, eta_ok: etaOk, service_penalty: servicePenalty },
      suggested_bid: (p50 && p80) ? suggested : null,
      sla_window_minutes: 30,
      rationale: [
        `Lane median (p50) ${p50 > 0 ? '$'+p50 : 'n/a'}, high (p80) ${p80 > 0 ? '$'+p80 : 'n/a'}`,
        servicePenalty > 0 ? 'Tight pickup window → service penalty applied' : 'Normal service window',
        hosOk ? 'Driver HOS feasible' : 'HOS tight — consider different driver',
      ],
    };
    return new Response(JSON.stringify(out), { status: 200 });
  } catch (e) {
    return new Response(JSON.stringify({ error: String(e) }), { status: 500 });
  }
});
