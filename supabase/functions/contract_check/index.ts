// Supabase Edge Function: contract_check
// Path: supabase/functions/contract_check/index.ts
// Invoke with: POST /functions/v1/contract_check
// Synthetic contract check that can raise alerts when failing.

import "jsr:@supabase/functions-js/edge-runtime";
import { serve } from "https://deno.land/std@0.224.0/http/server.ts";
import { createClient } from "npm:@supabase/supabase-js@2";

type Req = { org_id: string; route: string; ok: boolean; details?: unknown; severity?: "info" | "warning" | "critical" };

serve(async (req) => {
  if (req.method !== "POST") return new Response("method_not_allowed", { status: 405 });
  try {
    const body = (await req.json()) as Req;
    if (!body?.org_id || !body?.route) {
      return new Response("bad_request", { status: 400 });
    }

    const supa = createClient(
      Deno.env.get("SUPABASE_URL")!,
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
    );

    if (!body.ok) {
      // Fire-and-forget alert RPC; ignore errors to keep EF resilient
      await supa.rpc("fn_raise_alert", {
        p_org_id: body.org_id,
        p_severity: body.severity ?? "warning",
        p_code: `contract:${body.route}`,
        p_payload: body.details ?? {},
      });
    }

    return new Response(JSON.stringify({ ok: true }), { status: 200 });
  } catch (e) {
    return new Response(JSON.stringify({ ok: false, error: String(e) }), { status: 500 });
  }
});
