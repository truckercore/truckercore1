// functions/eld/log_safety_event/index.ts
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.46.1";

Deno.serve(async (req) => {
  try {
    if (req.method !== "POST") {
      return new Response(JSON.stringify({ error: "method_not_allowed" }), { status: 405, headers: { "content-type": "application/json" } });
    }
    const { driver_id, org_id, vehicle_id, event_type, confidence, source, metadata } = await req.json();
    if (!driver_id || !org_id || !event_type) {
      return new Response(JSON.stringify({ error: "missing_required" }), { status: 400, headers: { "content-type": "application/json" } });
    }
    const sb = createClient(
      Deno.env.get("SUPABASE_URL")!,
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
      { auth: { persistSession: false } }
    );
    const { data, error } = await sb
      .from("safety_events")
      .insert({ driver_id, org_id, vehicle_id, event_type, confidence, source, metadata })
      .select()
      .single();
    if (error) return new Response(JSON.stringify({ error: error.message }), { status: 400, headers: { "content-type": "application/json" } });

    // Optional: publish coaching trigger (observability only in this stub)
    console.log(JSON.stringify({ mod: "eld", ev: "coach_trigger", driver_id, event_type }));

    return new Response(JSON.stringify({ ok: true, data }), { headers: { "content-type": "application/json" } });
  } catch (e) {
    return new Response(JSON.stringify({ error: String(e?.message ?? e) }), { status: 400, headers: { "content-type": "application/json" } });
  }
});
