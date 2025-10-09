// supabase/functions/price_suggestions/index.ts
// Example Edge Function demonstrating org guard + insert into price_suggestions
// Invoke: POST /functions/v1/price_suggestions
// Body: { org_id, user_id, load_id, suggested_cpm, min_cpm?, max_cpm?, acceptance_likelihood?, reasons?: string[], confidence? }

import "jsr:@supabase/functions-js/edge-runtime";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { requireOrg } from "./guard.ts";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;

const sb = createClient(
  SUPABASE_URL,
  SERVICE_ROLE_KEY,
  { auth: { persistSession: false } },
);

Deno.serve(async (req) => {
  try {
    if (req.method !== "POST") {
      return new Response(JSON.stringify({ ok: false, error: "method_not_allowed" }), { status: 405 });
    }

    const input = await req.json();
    const check = requireOrg(req.headers, String(input?.org_id ?? ""));
    if (!check.ok) return check.res;

    const payload = {
      org_id: input.org_id,
      user_id: input.user_id,
      load_id: input.load_id,
      suggested_cpm: input.suggested_cpm,
      min_cpm: input.min_cpm ?? null,
      max_cpm: input.max_cpm ?? null,
      acceptance_likelihood: input.acceptance_likelihood ?? null,
      reasons: Array.isArray(input.reasons) ? input.reasons : [],
      confidence: input.confidence ?? null,
    };

    const { error } = await sb.from("price_suggestions").insert(payload);
    if (error) {
      return new Response(
        JSON.stringify({ ok: false, error: error.message }),
        { status: 400, headers: { "content-type": "application/json" } },
      );
    }

    return new Response(
      JSON.stringify({ ok: true }),
      { status: 200, headers: { "content-type": "application/json" } },
    );
  } catch (e) {
    return new Response(
      JSON.stringify({ ok: false, error: String(e) }),
      { status: 500, headers: { "content-type": "application/json" } },
    );
  }
});
