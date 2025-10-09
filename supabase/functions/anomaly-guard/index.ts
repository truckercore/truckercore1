// TypeScript
import { serve } from "https://deno.land/std@0.224.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const url = Deno.env.get("SUPABASE_URL")!;
const key = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
const supabase = createClient(url, key, { auth: { persistSession: false } });

serve(async (req) => {
  try {
    const { org_id, driver_id, last_n = 200 } = await req.json();
    const { data: pts, error } = await supabase
      .from("telemetry_points")
      .select("ts,lat,lng,speed_kph,confidence")
      .eq("org_id", org_id)
      .eq("driver_id", driver_id)
      .order("ts", { ascending: false })
      .limit(last_n);

    if (error) return new Response(error.message, { status: 500 });

    const flags: Array<{ ts: string; reason: string }> = [];
    for (const p of pts ?? []) {
      const speed = Number((p as any).speed_kph ?? 0);
      const conf = Number((p as any).confidence ?? 1);
      if (speed > 160 || conf < 0.3) {
        flags.push({ ts: (p as any).ts as string, reason: "speed_or_low_confidence" });
      }
    }

    if (flags.length) {
      await supabase.from("audit_log").insert({ org_id, action: "anomaly_detected", meta: { driver_id, flags } });
    }

    return new Response(JSON.stringify({ flags }), { headers: { "content-type": "application/json" }});
  } catch (e) {
    return new Response(String(e), { status: 500 });
  }
});