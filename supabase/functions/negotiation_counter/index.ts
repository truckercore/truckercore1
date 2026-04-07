// Supabase Edge Function (Deno) — Negotiation Assistant (lane-aware)
// Input:  { org_id, user_id, load_id, broker_id, offer_cpm, market_mid_cpm?, bounds? }
// Output: { ok, counter_cpm, likelihood_pct, rationale[] }

import "jsr:@supabase/functions-js/edge-runtime";
import { serve } from "https://deno.land/std@0.224.0/http/server.ts";
import { createClient } from "npm:@supabase/supabase-js@2";
import { hmacValid } from "./utils.ts";

type Req = {
  org_id: string;
  user_id: string;
  load_id: string;
  broker_id: string;
  offer_cpm: number;
  market_mid_cpm?: number;
  bounds?: { min?: number; max?: number }; // relative bounds (-0.10 .. +0.15)
};

type Res = {
  ok: boolean;
  counter_cpm?: number;
  likelihood_pct?: number;
  rationale?: string[];
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
    if (!body?.org_id || !body?.user_id || !body?.load_id || !body?.broker_id || typeof body?.offer_cpm !== "number") {
      return json({ ok: false, error: "bad_request" } as Res, 400);
    }

    const supa = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY);

    // Resolve bounds from prefs or request override
    let minB = -0.10, maxB = +0.15;
    try {
      const prefs = await supa.rpc("fn_get_prefs");
      const nb = (prefs as any)?.data?.negotiation_bounds ?? {};
      if (typeof body.bounds?.min === "number") minB = body.bounds.min;
      else if (typeof nb.min === "number") minB = nb.min;
      if (typeof body.bounds?.max === "number") maxB = body.bounds.max;
      else if (typeof nb.max === "number") maxB = nb.max;
    } catch {
      // ignore prefs fetch errors
    }

    // Anchor: use market mid if provided; else use offer
    const anchor = typeof body.market_mid_cpm === "number" ? body.market_mid_cpm : body.offer_cpm;

    // Heuristic relative change: aim +8%, clamp to bounds
    let rel = 0.08;
    rel = Math.max(minB, Math.min(maxB, rel));
    const counter_cpm = +(anchor * (1 + rel)).toFixed(2);

    // Likelihood heuristic: tighter counters => higher likelihood
    const likelihood = Math.max(0.1, 0.75 - Math.abs(rel) / 0.25);
    const rationale = [
      `anchored to ${typeof body.market_mid_cpm === "number" ? "market mid" : "offer"}`,
      `bounded to ${Math.round(minB * 100)}%..+${Math.round(maxB * 100)}%`,
    ];

    // Persist negotiation record
    await supa.from("negotiations").insert({
      org_id: body.org_id,
      user_id: body.user_id,
      load_id: body.load_id,
      broker_id: body.broker_id,
      offer_cpm: body.offer_cpm,
      counter_cpm,
      likelihood,
    });

    // Audit trail
    await supa.from("activity_log").insert({
      org_id: body.org_id,
      user_id: body.user_id,
      action: "negotiation.counter",
      target: body.load_id,
      details: { offer_cpm: body.offer_cpm, counter_cpm, bounds: { minB, maxB }, likelihood },
    });

    return json({ ok: true, counter_cpm, likelihood_pct: Math.round(likelihood * 100), rationale } as Res, 200);
  } catch (e) {
    return json({ ok: false, error: String(e) } as Res, 500);
  }
});
