import 'jsr:@supabase/functions-js/edge-runtime';
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.45.4';

const sb = createClient(
  Deno.env.get('SUPABASE_URL')!,
  Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
);

const html = (k: any) => `
  <h2>Weekly Fleet Summary</h2>
  <ul>
    <li>Loads created: ${k.loads_total}</li>
    <li>Loads delivered: ${k.loads_delivered}</li>
    <li>AI matches run: ${k.ai_matches}</li>
    <li>Geofence events: ${k.geofence_events}</li>
    <li>Safety incidents: ${k.incidents}</li>
  </ul>
  <p>Generated: ${new Date().toISOString()}</p>
`;

Deno.serve(async () => {
  // active schedules
  const { data: schedules, error: sErr } = await sb
    .from('exec_reports')
    .select('id, recipients, cadence, active')
    .eq('active', true);
  if (sErr) return new Response(JSON.stringify({ error: sErr.message }), { status: 500 });
  if (!schedules?.length) return new Response(JSON.stringify({ sent: 0 }), { status: 200 });

  // KPIs
  const { data: kpiRows, error: kErr } = await sb.from('exec_kpis_last_7d').select('*').limit(1);
  if (kErr) return new Response(JSON.stringify({ error: kErr.message }), { status: 500 });
  const k = kpiRows?.[0] ?? { loads_total:0, loads_delivered:0, ai_matches:0, geofence_events:0, incidents:0 };

  // queue emails via outbound_emails
  let sent = 0;
  for (const s of schedules) {
    const { error: e } = await sb.from('outbound_emails').insert({
      to_addresses: (s as any).recipients,                 // text[] (adjust if your schema differs)
      subject: 'Weekly Fleet Summary',
      body_html: html(k),
      body_text: `Loads: ${k.loads_total}, Delivered: ${k.loads_delivered}, AI: ${k.ai_matches}, Geofence: ${k.geofence_events}, Safety: ${k.incidents}`
    });
    if (!e) sent++;
  }
  return new Response(JSON.stringify({ sent }), { status: 200 });
});