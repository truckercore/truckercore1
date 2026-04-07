import { serve } from "https://deno.land/std@0.224.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const SECRET = Deno.env.get("AI_PLAN_HMAC")!;

async function hmacHex(s: string) {
  const key = await crypto.subtle.importKey(
    "raw",
    new TextEncoder().encode(SECRET),
    { name: "HMAC", hash: "SHA-256" },
    false,
    ["sign"],
  );
  const sig = await crypto.subtle.sign("HMAC", key, new TextEncoder().encode(s));
  return Array.from(new Uint8Array(sig)).map(b => b.toString(16).padStart(2, "0")).join("");
}

serve(async (req) => {
  const { planId } = await req.json();
  const admin = createClient(Deno.env.get('SUPABASE_URL')!, Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!);
  const { data: plan, error } = await admin.from('ai_action_plans').select('*').eq('id', planId).single();
  if (error) return new Response(error.message, { status: 400 });

  const canonical = JSON.stringify(plan.plan);
  const sig = await hmacHex(canonical);
  if (sig !== plan.signature) return new Response("invalid signature", { status: 403 });

  // TODO: server-side validations (role bounds, HOS/hazmat rules) before applying any action.
  return new Response(JSON.stringify({ ok: true }), { headers: { "content-type": "application/json" } });
});
