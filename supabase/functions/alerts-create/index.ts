// TypeScript
// supabase/functions/alerts-create/index.ts
// Deploy: supabase functions deploy alerts-create --no-verify-jwt
import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

export const handler = async (req: Request) => {
  if (req.method !== "POST") return new Response("Method Not Allowed", { status: 405 });
  try {
    const { driver_id, org_id, hazard, distance_ahead_m, suggested_speed_kph } = await req.json();

    const url = Deno.env.get("SUPABASE_URL")!;
    const key = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
    const supabase = createClient(url, key, { auth: { persistSession: false } });

    // Insert hazard record (simple audit). This uses the lightweight hazards table defined in safety_core.
    const { data: hz, error: hzErr } = await supabase
      .from("hazards")
      .insert({
        source: hazard.source,
        type: hazard.type,
        severity: hazard.severity,
        lat: hazard.lat,
        lng: hazard.lng,
        radius_m: hazard.radius_m ?? 500,
        corridor_id: hazard.corridor_id ?? null,
        expires_at: hazard.expires_at ?? null,
      })
      .select()
      .single();
    if (hzErr) return new Response(JSON.stringify({ error: hzErr.message }), { status: 400 });

    const kind = hazard.type === "sudden_slowdown" ? "slowdown_ahead" : hazard.type;

    const { data: alert, error } = await supabase
      .from("driver_alerts")
      .insert({
        driver_id,
        org_id,
        hazard_id: hz.id,
        kind,
        distance_ahead_m: distance_ahead_m ?? null,
        suggested_speed_kph: suggested_speed_kph ?? null,
        ack_deadline_at: new Date(Date.now() + 60_000).toISOString(),
      })
      .select()
      .single();

    if (error) return new Response(JSON.stringify({ error: error.message }), { status: 400 });
    return new Response(JSON.stringify({ alert }), { headers: { "Content-Type": "application/json" } });
  } catch (e) {
    return new Response(JSON.stringify({ error: String(e) }), { status: 500 });
  }
};

Deno.serve(handler);
