import 'jsr:@supabase/functions-js/edge-runtime';
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.45.4';
const sb = createClient(Deno.env.get('SUPABASE_URL')!, Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!);
const SMTP_URL = Deno.env.get('SMTP_URL')!; // or Resend endpoint

Deno.serve(async () => {
  try {
    const { data, error } = await sb.from('v_exec_weekly').select('*').limit(4);
    if (error) return new Response(JSON.stringify({ error: error.message }), { status: 500 });

    const rows = (data||[]).map((r:any) =>
      `<tr><td>${new Date(r.week).toISOString().slice(0,10)}</td><td>${r.total_loads}</td><td>$${Number(r.revenue).toFixed(2)}</td><td>$${Number(r.costs).toFixed(2)}</td><td>$${Number(r.profit).toFixed(2)}</td></tr>`
    ).join('');
    const html = `<h3>Weekly Ops Summary</h3><table border="1" cellpadding="6"><tr><th>Week</th><th>Loads</th><th>Revenue</th><th>Costs</th><th>Profit</th></tr>${rows}</table>`;

    await fetch(SMTP_URL, { method:'POST', headers:{'Content-Type':'application/json'}, body: JSON.stringify({
      to: ['execs@customer.com'], subject: 'Weekly Ops Summary', html
    })});

    try { await sb.from('metrics_events').insert({ kind: 'weekly_report_sent', props: { rows: (data||[]).length } }); } catch (_) {}
        return new Response(JSON.stringify({ sent: true }), { status: 200 });
  } catch (e:any) {
    return new Response(JSON.stringify({ error: e?.message || 'send error' }), { status: 500 });
  }
});