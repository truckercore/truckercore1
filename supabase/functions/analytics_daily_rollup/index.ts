// /supabase/functions/analytics_daily_rollup/index.ts
// deno run --allow-env --allow-net
import 'jsr:@supabase/functions-js/edge-runtime';
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.45.4';

type Snap = {
  org_id: string;
  date_bucket: string; // 'YYYY-MM-DD'
  scope: 'fleet' | 'broker';
  total_loads: number;
  total_miles: number;
  revenue_usd: number;
  cost_usd: number;
  avg_ppm: number | null;
  on_time_pct: number | null;
};

const SUPABASE_URL = Deno.env.get('SUPABASE_URL')!;
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!;
const sb = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY, { auth: { persistSession: false } });

const ymd = (d: Date) => d.toISOString().slice(0, 10);

Deno.serve(async () => {
  try {
    // Yesterday (UTC)
    const now = new Date();
    const y = new Date(Date.UTC(now.getUTCFullYear(), now.getUTCMonth(), now.getUTCDate() - 1));
    const from = new Date(y); from.setUTCHours(0, 0, 0, 0);
    const to = new Date(y);   to.setUTCHours(23, 59, 59, 999);

    // Find orgs with activity (adjust loads table if needed)
    const { data: orgRows, error: orgErr } = await sb
      .from('v_loads_with_org')
      .select('*')
      .gte('updated_at', from.toISOString())
      .lte('updated_at', to.toISOString());
    if (orgErr) throw orgErr;

    const norm = (r: any) => (r?.org_id ?? r?.org_id_derived ?? null) as string | null;
    const orgIds = Array.from(new Set((orgRows ?? []).map(norm))).filter(Boolean) as string[];
    const snaps: Snap[] = [];

    for (const org_id of orgIds) {
      const fleet = await computeSnapshot(org_id, from, to, 'fleet');
      if (fleet) snaps.push(fleet);
      const broker = await computeSnapshot(org_id, from, to, 'broker');
      if (broker) snaps.push(broker);
    }

    if (snaps.length) {
      const { error: upErr } = await sb.from('analytics_snapshots').upsert(snaps, {
        onConflict: 'org_id,date_bucket,scope',
        ignoreDuplicates: false,
      });
      if (upErr) throw upErr;
    }

    return new Response(JSON.stringify({ date: ymd(y), upserted: snaps.length }), { status: 200 });
  } catch (e) {
    return new Response(JSON.stringify({ error: String(e) }), { status: 500 });
  }
});

async function computeSnapshot(org_id: string, from: Date, to: Date, scope: 'fleet' | 'broker') {
  // TODO: adjust scope filter if your schema differentiates 'broker' vs 'fleet'
  const { data: rows, error } = await sb
    .from('v_loads_with_org')
    .select('id, miles, rate_usd_total, delivered_at, delivery_appt_at, status, org_id, org_id_derived')
    .gte('delivered_at', from.toISOString())
    .lte('delivered_at', to.toISOString())
    .eq('status', 'delivered');
  if (error) throw error;
  const norm = (r: any) => (r?.org_id ?? r?.org_id_derived ?? null) as string | null;
  const filtered = (rows ?? []).filter(r => norm(r) === org_id);
  if (!filtered.length) return null;

  let total_loads = rows.length;
  let total_miles = 0;
  let revenue_usd = 0;
  let cost_usd = 0;
  let on_time_count = 0;

  for (const r of rows) {
    const miles = Number(r.miles ?? 0);
    total_miles += miles;
    const rev = Number(r.rate_usd_total ?? 0); // Or miles * rate_per_mile if needed
    revenue_usd += rev;
    if (r.delivery_appt_at && r.delivered_at) {
      on_time_count += (new Date(r.delivered_at).getTime() <= new Date(r.delivery_appt_at).getTime()) ? 1 : 0;
    }
  }
  const avg_ppm = total_miles > 0 ? Number((revenue_usd / total_miles).toFixed(4)) : null;
  const on_time_pct = total_loads > 0 ? Number(((on_time_count / total_loads) * 100).toFixed(2)) : null;

  return {
    org_id,
    date_bucket: ymd(from),
    scope,
    total_loads,
    total_miles,
    revenue_usd,
    cost_usd,
    avg_ppm,
    on_time_pct,
  } as Snap;
}
