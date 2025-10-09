// supabase/functions/interpreter/index.ts
// Deno Edge Function: create interpreter session room and log CDR
import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

Deno.serve(async (req) => {
  try {
    if (req.method !== "POST") return new Response("Method not allowed", { status: 405 });

    const supabaseUrl = Deno.env.get("SUPABASE_URL");
    const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
    if (!supabaseUrl || !serviceKey) return new Response("Supabase env not configured", { status: 500 });

    const supabase = createClient(supabaseUrl, serviceKey, { auth: { persistSession: false } });

    const { trip_id } = await req.json().catch(() => ({}));
    const roomId = crypto.randomUUID();

    const { error } = await supabase.from("interpreter_calls").insert({
      room_id: roomId,
      trip_id: trip_id ?? null,
      status: "created",
      created_at: new Date().toISOString(),
    });
    if (error) return new Response(error.message, { status: 500 });

    // TODO: Integrate vendor session creation and persist vendor_session_id.
    return new Response(JSON.stringify({ roomId }), { headers: { "Content-Type": "application/json" } });
  } catch (e) {
    return new Response(String(e), { status: 500 });
  }
});
