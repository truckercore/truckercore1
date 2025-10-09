// Supabase Edge Function: Referrals - Create Code
// Path: supabase/functions/referrals/create-code/index.ts
// Invoke with: POST /functions/v1/referrals/create-code { org_id, created_by }
// Returns: { ok, code, url }

import "jsr:@supabase/functions-js/edge-runtime";
import { serve } from "https://deno.land/std@0.224.0/http/server.ts";
import { createClient } from "npm:@supabase/supabase-js@2";

const SB = createClient(
  Deno.env.get("SUPABASE_URL")!,
  Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
  { auth: { persistSession: false } },
);

function genCode(len = 8) {
  const alphabet = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789";
  let s = ""; for (let i = 0; i < len; i++) s += alphabet[Math.floor(Math.random() * alphabet.length)];
  return s;
}

serve(async (req) => {
  try {
    if (req.method !== "POST") return new Response("Method not allowed", { status: 405 });
    const body = await req.json().catch(() => ({} as any));
    const org_id = body.org_id as string;
    const created_by = body.created_by as string; // could be derived from auth in non-service contexts

    if (!org_id || !created_by) {
      return new Response(JSON.stringify({ ok: false, error: "missing_params" }), { status: 400 });
    }

    // Generate unique referral code (best-effort retries)
    let code = genCode();
    for (let i = 0; i < 5; i++) {
      const exists = await SB.from("referral_codes").select("code").eq("code", code).maybeSingle();
      if (!exists.data) break;
      code = genCode();
    }

    // Map to existing schema if applicable: issuer_org_id, issuer_user_id
    const insert = await SB.from("referral_codes").insert({
      code,
      issuer_org_id: org_id,
      issuer_user_id: created_by,
      audience: null,
      max_uses: 100,
    });
    if (insert.error) throw insert.error;

    const shareUrl = `${Deno.env.get("WEB_URL") ?? "https://app.truckercore.com"}/signup?ref=${code}`;
    return new Response(JSON.stringify({ ok: true, code, url: shareUrl }), { status: 200 });
  } catch (e) {
    return new Response(JSON.stringify({ ok: false, error: String(e) }), { status: 500 });
  }
});
