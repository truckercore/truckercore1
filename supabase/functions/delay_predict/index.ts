// Supabase Edge Function (Deno) — Delay Prediction (heuristics v1)
// Input:  { org_id, candidate_id, route_polyline?, start_time, corridor?, facility_id? }
// Output: { ok, on_time_prob, late_risk_reason, mitigation }

import "jsr:@supabase/functions-js/edge-runtime";
import { serve } from "https://deno.land/std@0.224.0/http/server.ts";
import { createClient } from "npm:@supabase/supabase-js@2";
import { hmacValid } from "./utils.ts";

type Req = {
  org_id: string;
  candidate_id: string;
  route_polyline?: string;
  start_time: string;       // ISO
  corridor?: string[];      // e.g., ['I-80','I-94']
  facility_id?: string;
};

type Res = {
  ok: boolean;
  on_time_prob?: number;      // 0..1
  late_risk_reason?: string;
  mitigation?: string | null;
  error?: string;
};

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

function json(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), { status, headers: { "Content-Type": "application/json", ...corsHeaders } });
}

const SUPABASE_URL = Deno.env.get("SUPABASE_URL");
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");

serve(async (req: Request) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });

  try {
    if (!SUPABASE_URL || !SUPABASE_SERVICE_ROLE_KEY) return json({ ok: false, error: "server_misconfigured" } as Res, 500);

    const raw = await req.text();
    const secret = Deno.env.get("INTEGRATIONS_SIGNING_SECRET") ?? "";
    if (!(await hmacValid(secret, raw, req.headers.get("x-signature")))) {
      return new Response("invalid signature", { status: 401, headers: corsHeaders });
    }

    const body = JSON.parse(raw) as Req;
    if (!body?.org_id || !body?.candidate_id || !body?.start_time) {
      return json({ ok: false, error: "bad_request" } as Res, 400);
    }

    const supa = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY);

    let on_time_prob = 0.85;
    const reasons: string[] = [];
    const mitigations: string[] = [];

    // Corridor traffic heuristic
    const corridors = body.corridor ?? [];
    if (corridors.includes("I-80")) {
      on_time_prob -= 0.15;
      reasons.push("I-80 congestion");
      mitigations.push("Depart 45m earlier");
    }

    // Facility dwell priors
    if (body.facility_id) {
      const { data: fac } = await supa
        .from("facility_dwell_stats")
        .select("avg_dwell_min,late_prob")
        .eq("facility_id", body.facility_id)
        .maybeSingle();

      if (fac?.late_prob && fac.late_prob > 0.3) {
        on_time_prob -= Math.min(0.2, Number(fac.late_prob));
        reasons.push(`Facility dwell ${fac.avg_dwell_min}m`);
      }
    }

    // Optional: weather/risk labels could reduce on_time_prob slightly
    // on_time_prob -= 0.05; reasons.push('Storm risk');

    on_time_prob = Math.max(0, Math.min(1, on_time_prob));

    // Audit trail
    await supa.from("activity_log").insert({
      org_id: body.org_id,
      action: "delay.predict",
      target: body.candidate_id,
      details: { on_time_prob, reasons, mitigations },
    });

    return json({
      ok: true,
      on_time_prob,
      late_risk_reason: reasons.join("; ") || "Nominal",
      mitigation: mitigations[0] ?? null,
    } as Res, 200);
  } catch (e) {
    return json({ ok: false, error: String(e) } as Res, 500);
  }
});
