// Path: supabase/functions/sync-motive/index.ts
// Minimal Motive sync stub: reads provider token from DB and simulates ingesting HOS segments
import 'jsr:@supabase/functions-js/edge-runtime';
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.45.4';

const SUPABASE_URL = Deno.env.get('SUPABASE_URL')!;
const SERVICE_KEY = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!;

Deno.serve(async (req) => {
  try {
    if (req.method !== 'POST') return new Response('Use POST', { status: 405 });
    const body = await req.json().catch(() => ({}));
    const orgId = body?.org_id ?? null;

    const sb = createClient(SUPABASE_URL, SERVICE_KEY);

    // Load Motive token for the org (or global)
    const { data: t, error: terr } = await sb
      .from('provider_tokens')
      .select('id, token, org_id')
      .eq('provider', 'motive')
      .order('updated_at', { ascending: false })
      .limit(1)
      .maybeSingle();
    if (terr) throw terr;
    if (!t?.token) return new Response(JSON.stringify({ error: 'No Motive token stored' }), { status: 400 });

    // Simulate pull: normally call Motive API with t.token
    // Here we create 2 example HOS segments and insert into motive_hos_staging
    const now = new Date();
    const s1Start = new Date(now.getTime() - 4 * 3600_000).toISOString();
    const s1End = new Date(now.getTime() - 2 * 3600_000).toISOString();
    const s2Start = s1End;
    const s2End = now.toISOString();

    const records = [
      { driver_id: 'drv_demo_1', start: s1Start, end: s1End, status: 'driving', src_payload: { src: 'motive', example: true } },
      { driver_id: 'drv_demo_1', start: s2Start, end: s2End, status: 'on_duty', src_payload: { src: 'motive', example: true } },
    ];

    const { error: insErr } = await sb.from('motive_hos_staging').insert(records);
    if (insErr) throw insErr;

    return new Response(JSON.stringify({ ok: true, inserted: records.length }), { headers: { 'content-type': 'application/json' } });
  } catch (e) {
    console.error(e);
    return new Response(JSON.stringify({ error: String(e) }), { status: 500 });
  }
});
