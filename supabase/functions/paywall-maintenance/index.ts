// supabase/functions/paywall-maintenance/index.ts
import { serve } from "https://deno.land/std@0.224.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.57.2";

serve(async () => {
  const url = Deno.env.get("SUPABASE_URL");
  const key = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") || Deno.env.get("SERVICE_ROLE_KEY");
  if (!url || !key) return new Response("missing env", { status: 500 });
  const s = createClient(url, key, { auth: { persistSession: false } });

  // Delete expired used nonces; also sweep very old expired ones (>24h)
  const nowIso = new Date().toISOString();
  const oldIso = new Date(Date.now() - 24 * 3600 * 1000).toISOString();
  await s.from("paywall_nonces")
    .delete()
    .or(`and(used_at.not.is.null,expires_at.lte.${nowIso}),and(used_at.is.null,expires_at.lte.${oldIso})`);

  return new Response("ok");
});
