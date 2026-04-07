// TypeScript
import { serve } from "https://deno.land/std@0.224.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const url = Deno.env.get("SUPABASE_URL")!;
const key = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
const supabase = createClient(url, key, { auth: { persistSession: false } });

serve(async () => {
  const { error } = await supabase.rpc("purge_old_telemetry");
  if (error) {
    console.error(error);
    return new Response("error", { status: 500 });
  }
  await supabase.from("audit_log").insert({ action: "retention_purge", meta: {}, org_id: null });
  return new Response("ok");
});