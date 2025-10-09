import "jsr:@supabase/functions-js/edge-runtime";
import { createClient } from "npm:@supabase/supabase-js@2";
import { serve } from "https://deno.land/std@0.224.0/http/server.ts";

type Inspection = {
  org_id?: string;
  driver_user_id: string;
  vehicle_id: string;
  type: "pre_trip" | "post_trip";
  defects: any[]; // array of defect objects
  certified_safe: boolean;
  signed_at?: string; // ISO
};

const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const SERVICE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;

function getReqId(req: Request) {
  return req.headers.get('x-request-id') || crypto.randomUUID();
}

serve(async (req) => {
  try {
    if (req.method !== "POST") return new Response("Use POST", { status: 405 });
    const payload = (await req.json()) as Inspection;
    if (!payload?.driver_user_id || !payload.vehicle_id || !payload.type) {
      return new Response(JSON.stringify({ error: "missing fields" }), { status: 400 });
    }
    const supabase = createClient(SUPABASE_URL, SERVICE_KEY);

    const { data, error } = await supabase.from("inspection_reports").insert({
      org_id: payload.org_id ?? null,
      driver_user_id: payload.driver_user_id,
      vehicle_id: payload.vehicle_id,
      type: payload.type,
      defects: payload.defects ?? [],
      certified_safe: payload.certified_safe ?? true,
      signed_at: payload.signed_at ?? new Date().toISOString(),
    }).select("id, certified_safe").single();
    if (error) return new Response(JSON.stringify({ error: error.message }), { status: 500 });

    // If defects exist and not certified_safe, emit an alert event for fleet dashboard
    if ((payload.defects?.length ?? 0) > 0 && !payload.certified_safe) {
      await supabase.from("alerts_events").insert({
        org_id: payload.org_id ?? null,
        severity: "warning",
        code: "inspection_defects_open",
        payload: { driver_user_id: payload.driver_user_id, vehicle_id: payload.vehicle_id, defects: payload.defects },
      });
    }

    return new Response(JSON.stringify({ id: data.id, request_id: getReqId(req) }), { headers: { "content-type": "application/json" } });
  } catch (e) {
    return new Response(JSON.stringify({ error: String(e) }), { status: 500 });
  }
});
