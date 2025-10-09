import { serve } from "https://deno.land/std@0.224.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const url = Deno.env.get('SUPABASE_URL')!;
const key = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!;
const ALERT_WEBHOOK = Deno.env.get('ALERT_WEBHOOK_URL')!;

serve(async () => {
  const s = createClient(url, key);
  await s.rpc('validate_rls_policies');
  const { data, error } = await s
    .from('rls_validation_results')
    .select('*')
    .order('ran_at', { ascending: false })
    .limit(50);
  if (error) return new Response(error.message, { status: 500 });

  const failed = (data as any[] ?? []).filter((r: any) => !r.has_rls || (r.select_policies ?? 0) === 0);
  if (failed.length > 0) {
    await fetch(ALERT_WEBHOOK, {
      method: 'POST',
      headers: { 'Content-Type':'application/json' },
      body: JSON.stringify({ text: `RLS validation failures:\n${failed.map((f:any)=>`${f.table_name} (has_rls=${f.has_rls}, select=${f.select_policies})`).join('\n')}` })
    });
  }
  return new Response(JSON.stringify({ ok: true, checked: (data?.length ?? 0), failures: failed.length }),
    { headers: { "Content-Type":"application/json" }});
});