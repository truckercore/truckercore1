import { serve } from "https://deno.land/std@0.224.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

serve(async () => {
  const admin = createClient(Deno.env.get('SUPABASE_URL')!, Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!);
  const { data, error } = await admin.rpc('explain_query', { q: 'select * from loads_visible limit 1' });
  return new Response(JSON.stringify({ plan: data, error }), { headers: { 'content-type': 'application/json' } });
});
