// Supabase Edge Function: Referral Generate
// Path: supabase/functions/referral_generate/index.ts
// Invoke with: POST /functions/v1/referral_generate { issuer_user_id, issuer_org_id?, audience, max_uses?, expires_at? }

import "jsr:@supabase/functions-js/edge-runtime";
import { serve } from "https://deno.land/std@0.224.0/http/server.ts";
import { createClient } from "npm:@supabase/supabase-js@2";

function randCode(n = 8) {
  const chars = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789";
  let s = "";
  for (let i = 0; i < n; i++) s += chars[Math.floor(Math.random() * chars.length)];
  return s;
}

serve(async (req) => {
  try {
    if (req.method !== "POST") return new Response("Method not allowed", { status: 405 });
    const supa = createClient(
      Deno.env.get("SUPABASE_URL")!,
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
      { auth: { persistSession: false }, global: { headers: { Authorization: req.headers.get("Authorization") ?? "" } } },
    );

    const { issuer_user_id, issuer_org_id, audience, max_uses, expires_at } = await req.json();
    if (!issuer_user_id || !audience) return new Response("bad_request", { status: 400 });

    let code = randCode();
    // Best-effort uniqueness checks (retry a few times)
    for (let i = 0; i < 5; i++) {
      const { data } = await supa.from("referral_codes").select("code").eq("code", code).maybeSingle();
      if (!data) break;
      code = randCode();
    }

    const { error } = await supa.from("referral_codes").insert({
      code,
      issuer_user_id,
      issuer_org_id: issuer_org_id ?? null,
      audience,
      max_uses: max_uses ?? 100,
      expires_at: expires_at ?? null,
    });
    if (error) throw error;

    const shareUrl = `${Deno.env.get("WEB_URL") ?? "https://app.example.com"}/r/${code}`;
    return new Response(JSON.stringify({ ok: true, code, url: shareUrl }), { status: 200 });
  } catch (e) {
    return new Response(JSON.stringify({ ok: false, error: String(e) }), { status: 500 });
  }
});
