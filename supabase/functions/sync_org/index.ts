import 'jsr:@supabase/functions-js/edge-runtime.d.ts';
import { createClient } from 'jsr:@supabase/supabase-js@2';

const SUPABASE_URL = Deno.env.get('SUPABASE_URL')!;
const SERVICE_ROLE = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!;

const supabase = createClient(SUPABASE_URL, SERVICE_ROLE, { auth: { persistSession: false } });

async function syncOrg(org_id: string) {
  // Try provider token (motive)
  const { data: acct } = await supabase
    .from('integrations.provider_accounts')
    .select('access_token')
    .eq('org_id', org_id)
    .eq('provider', 'motive')
    .single();

  if (!acct?.access_token) {
    // simulate one tick if no token
    const { data: trucks } = await supabase
      .from('trucks')
      .select('id')
      .eq('carrier_id', org_id)
      .limit(50);

    if (!trucks?.length) return;

    const baseLat = 40.72, baseLng = -74.0;
    const rows = trucks.map(t => ({
      org_id,
      truck_id: t.id,
      lat: baseLat + Math.random() / 50,
      lng: baseLng + Math.random() / 50,
      speed_kph: Math.random() * 85,
      heading: Math.random() * 360,
      odometer_km: Math.random() * 500000,
      gps_ts: new Date().toISOString(),
      provider: 'simulator',
      raw: null,
    }));

    await supabase.from('vehicle_positions').insert(rows);
    return;
  }

  // TODO: Fetch Motive API with acct.access_token and insert into vehicle_positions
}

Deno.serve(async (req) => {
  try {
    const url = new URL(req.url);
    const org = url.searchParams.get('org_id');
    if (!org) return new Response('Missing org_id', { status: 400 });

    await syncOrg(org);

    return new Response(JSON.stringify({ ok: true }), {
      headers: { 'content-type': 'application/json' },
    });
  } catch (e) {
    return new Response(
      JSON.stringify({ ok: false, error: String(e) }),
      { status: 500, headers: { 'content-type': 'application/json' } },
    );
  }
});
