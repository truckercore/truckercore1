// TypeScript
// supabase/functions/alerts-ack/index.ts
// Deploy: supabase functions deploy alerts-ack --no-verify-jwt
import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

type Body = {
  alert_id: string;
  driver_id: string;
  org_id: string;
  acked_at_ms_from_alert?: number;
  chosen_speed_kph?: number;
  telem_window?: { avg_speed_kph: number; max_speed_kph: number; duration_s: number };
};

export const handler = async (req: Request) => {
  if (req.method !== "POST") return new Response("Method Not Allowed", { status: 405 });
  try {
    const url = Deno.env.get("SUPABASE_URL")!;
    const key = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
    const supabase = createClient(url, key, { auth: { persistSession: false } });
    const b = (await req.json()) as Body;

    const { data: alert, error: aErr } = await supabase
      .from("driver_alerts")
      .select("created_at, suggested_speed_kph")
      .eq("id", b.alert_id)
      .single();
    if (aErr || !alert) return new Response(JSON.stringify({ error: aErr?.message ?? "missing alert" }), { status: 404 });

    const latency_ms = b.acked_at_ms_from_alert ?? Math.max(0, Date.now() - new Date(alert.created_at as string).getTime());

    const suggested = alert.suggested_speed_kph ?? 9999;
    const guidance_followed = b.telem_window
      ? (b.telem_window.avg_speed_kph ?? suggested) <= suggested
      : (b.chosen_speed_kph ?? suggested) <= suggested;

    const { error } = await supabase.from("driver_acks").insert({
      alert_id: b.alert_id,
      driver_id: b.driver_id,
      org_id: b.org_id,
      latency_ms,
      chosen_speed_kph: b.chosen_speed_kph ?? null,
      guidance_followed,
    });

    if (error) return new Response(JSON.stringify({ error: error.message }), { status: 400 });
    return new Response(JSON.stringify({ ok: true, latency_ms, guidance_followed }), {
      headers: { "Content-Type": "application/json" },
    });
  } catch (e) {
    return new Response(JSON.stringify({ error: String(e) }), { status: 500 });
  }
};

Deno.serve(handler);
