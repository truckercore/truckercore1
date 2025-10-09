import { serve } from "https://deno.land/std@0.224.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

serve(async () => {
  const s = createClient(Deno.env.get('SUPABASE_URL')!, Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!);
  const { data, error } = await s.storage.from('exports').list('', { limit: 1000, search: '' });
  if (error) return new Response(error.message, { status: 500 });
  return new Response(JSON.stringify({ count: data?.length ?? 0, sample: data?.slice(0, 10) ?? [] }), {
    headers: { "content-type": "application/json" },
  });
});
