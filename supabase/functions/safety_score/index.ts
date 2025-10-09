import "jsr:@supabase/functions-js/edge-runtime";
import { createClient } from "npm:@supabase/supabase-js@2";
import { serve } from "https://deno.land/std@0.224.0/http/server.ts";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const SERVICE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;

serve(async (req) => {
  try {
    const url = new URL(req.url);
    const driver = url.searchParams.get("driver");
    if (!driver) return new Response("driver required", { status: 400 });

    const sb = createClient(SUPABASE_URL, SERVICE_KEY);
    const { data, error } = await sb
      .from("safety_incidents")
      .select("severity")
      .eq("driver_user_id", driver)
      .eq("resolved", false);
    if (error) throw error;

    const count = (data ?? []).length;
    const sevSum = (data ?? []).reduce((a, b) => a + ((b as any).severity ?? 0), 0);
    const score = Math.max(0, 100 - (count * 10 + sevSum * 5));
    return new Response(JSON.stringify({ driver, score }), { headers: { "content-type": "application/json" } });
  } catch (e) {
    return new Response(JSON.stringify({ error: String(e) }), { status: 500 });
  }
});