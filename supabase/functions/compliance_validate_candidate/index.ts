// Supabase Edge Function (Deno) — Compliance Validator (Pre-rank)
// Input:  { org_id, candidate_id, driver_state?, equipment, hazmat?, duty_hours_left?, lane? }
// Output: { ok, compliant: boolean, adjustments: {pickup_shift_min?}, reasons: string[] }

import "jsr:@supabase/functions-js/edge-runtime";
import { serve } from "https://deno.land/std@0.224.0/http/server.ts";
import { createClient } from "npm:@supabase/supabase-js@2";
import { hmacValid } from "./utils.ts";

type Req = {
  org_id: string;
  candidate_id: string;
  driver_state?: Record<string, unknown>;
  equipment: string; // 'van'|'reefer'|'flatbed'|...
  hazmat?: boolean;
  duty_hours_left?: number;
  lane?: {
    max_weight?: number;
    max_height?: number;
    facility_id?: string;
    window_start?: string;
    window_end?: string;
  };
};

type Res = {
  ok: boolean;
  compliant?: boolean;
  adjustments?: Record<string, unknown>;
  reasons?: string[];
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
    // Optional HMAC verification
    const secret = Deno.env.get("INTEGRATIONS_SIGNING_SECRET") ?? "";
    if (!(await hmacValid(secret, raw, req.headers.get("x-signature")))) {
      // If you prefer soft-fail in dev, change to 400. Keeping 401 for security.
      return new Response("invalid signature", { status: 401, headers: corsHeaders });
    }

    const body = JSON.parse(raw) as Req;
    if (!body?.org_id || !body?.candidate_id || !body?.equipment) {
      return json({ ok: false, error: "bad_request" } as Res, 400);
    }

    const supa = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY);

    // Load org/equipment compliance rules
    const { data: rules, error: rErr } = await supa
      .from("compliance_rules")
      .select("hazmat_allowed,max_weight,max_height")
      .eq("org_id", body.org_id)
      .eq("equipment", body.equipment)
      .maybeSingle();

    if (rErr) return json({ ok: false, error: `rules_error: ${rErr.message}` } as Res, 500);

    const reasons: string[] = [];
    const adjustments: Record<string, unknown> = {};

    // HOS check (MVP threshold: need ≥ 2 hours)
    if (typeof body.duty_hours_left === "number" && body.duty_hours_left < 2) {
      reasons.push("Insufficient duty hours (need ≥ 2h)");
      // Attempt an auto-tweak (UI can reflect this)
      adjustments["pickup_shift_min"] = 60;
    }

    // Weight/height checks against lane/rules
    const laneMaxW = body.lane?.max_weight ?? rules?.max_weight ?? null;
    const laneMaxH = body.lane?.max_height ?? rules?.max_height ?? null;
    const drvW = Number(body.driver_state?.["gross_weight"] ?? NaN);
    const drvH = Number(body.driver_state?.["height"] ?? NaN);

    if (laneMaxW && !Number.isNaN(drvW) && drvW > Number(laneMaxW)) {
      reasons.push(`Exceeds lane max weight (${drvW} > ${laneMaxW})`);
    }
    if (laneMaxH && !Number.isNaN(drvH) && drvH > Number(laneMaxH)) {
      reasons.push(`Exceeds lane max height (${drvH} > ${laneMaxH})`);
    }

    // Hazmat policy
    if (body.hazmat && rules?.hazmat_allowed !== true) {
      reasons.push("Hazmat not allowed for this equipment/org");
    }

    // Facility dwell/close window heuristic (optional)
    if (body.lane?.facility_id) {
      const { data: fac } = await supa
        .from("facility_dwell_stats")
        .select("avg_dwell_min,late_prob")
        .eq("facility_id", body.lane.facility_id)
        .maybeSingle();
      if (fac?.late_prob && fac.late_prob > 0.4) {
        reasons.push(`Facility late risk ${Math.round(fac.late_prob * 100)}%`);
      }
    }

    const strictBlock = reasons.some((x) => /Exceeds|Insufficient|Hazmat/.test(x));
    const compliant = !strictBlock;

    // Audit (optional)
    await supa.from("activity_log").insert({
      org_id: body.org_id,
      action: compliant ? "compliance.pass" : "compliance.block",
      target: body.candidate_id,
      details: { equipment: body.equipment, hazmat: !!body.hazmat, reasons, adjustments },
    });

    return json({ ok: true, compliant, adjustments, reasons } as Res, 200);
  } catch (e) {
    return json({ ok: false, error: String(e) } as Res, 500);
  }
});
