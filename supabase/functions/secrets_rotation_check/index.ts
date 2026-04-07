import { serve } from "https://deno.land/std@0.224.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const url = Deno.env.get('SUPABASE_URL')!;
const key = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!;
const ALERT_WEBHOOK = Deno.env.get('ALERT_WEBHOOK_URL')!;

serve(async () => {
  const s = createClient(url, key);
  const { data, error } = await s.from('secrets_registry').select('*');
  if (error) return new Response(error.message, { status: 500 });

  const now = Date.now();
  const stale = (data ?? []).filter((r: any) => {
    const ageDays = (now - Date.parse(r.rotated_at)) / 86400000;
    return ageDays > r.max_age_days;
  });

  if (stale.length > 0) {
    await fetch(ALERT_WEBHOOK, {
      method: 'POST',
      headers: {'Content-Type':'application/json'},
      body: JSON.stringify({ text: `Secrets rotation overdue: ${stale.map((s:any)=>s.key).join(', ')}` })
    });
  }
  return new Response(JSON.stringify({ ok: true, staleCount: stale.length }), { headers: {"Content-Type":"application/json"}});
});