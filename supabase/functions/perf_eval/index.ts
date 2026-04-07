import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const SERVICE_ROLE = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;

Deno.serve(async () => {
  const admin = createClient(SUPABASE_URL, SERVICE_ROLE, { auth: { persistSession: false } });
  const { error } = await admin.rpc("perf.evaluate_slo_and_alert");
  if (error) return new Response(error.message, { status: 500 });
  return new Response("ok", { status: 200 });
});