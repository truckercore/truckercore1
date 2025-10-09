// Supabase Edge Function: promotions.issue_qr (driver)
// POST /functions/v1/promotions.issue_qr { promo_id, device_hash?, location_hint? }
// Returns a short-lived JWT containing { promo_id, user_id, nonce, location_hint, exp, device_hash }

import "jsr:@supabase/functions-js/edge-runtime";
import { createClient } from "npm:@supabase/supabase-js@2";
import * as jose from "npm:jose@5.8.0";

const URL = Deno.env.get("SUPABASE_URL")!;
const ANON = Deno.env.get("SUPABASE_ANON") ?? Deno.env.get("SUPABASE_ANON_KEY");
if (!ANON) throw new Error("Missing SUPABASE_ANON (fallback SUPABASE_ANON_KEY not set)");
if (!Deno.env.get("SUPABASE_ANON") && Deno.env.get("SUPABASE_ANON_KEY")) {
  console.warn("[deprecation] SUPABASE_ANON_KEY is deprecated in Edge Functions; please set SUPABASE_ANON instead");
}
const SERVICE = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
const SECRET_PROMO_JWT_HS256 = Deno.env.get("SECRET_PROMO_JWT_HS256") ?? Deno.env.get("PROMO_JWT_SECRET") ?? Deno.env.get("SUPABASE_JWT_SECRET")!;

Deno.serve(async (req) => {
  try {
    if (req.method !== "POST") return new Response(JSON.stringify({ error: "METHOD_NOT_ALLOWED" }), { status: 405, headers: { "content-type": "application/json" } });
    const auth = req.headers.get("Authorization") ?? "";
    const user = createClient(URL, ANON, { global: { headers: { Authorization: auth } } });
    const admin = createClient(URL, SERVICE);

    const { data: ures } = await user.auth.getUser();
    if (!ures?.user) return new Response(JSON.stringify({ error: "AUTH_REQUIRED" }), { status: 401, headers: { "content-type": "application/json" } });

    const body = await req.json().catch(() => ({} as any));
    const promo_id = Number(body.promo_id);
    const device_hash = typeof body.device_hash === 'string' ? body.device_hash : null;
    const location_hint = typeof body.location_hint === 'string' ? body.location_hint : null;
    if (!promo_id) return new Response(JSON.stringify({ error: "MISSING_PROMO_ID" }), { status: 400, headers: { "content-type": "application/json" } });

    // Load promo and basic eligibility forecast
    const nowIso = new Date().toISOString();
    const { data: promo, error: perr } = await user
      .from("promotions")
      .select("id, org_id, start_at, end_at, per_user_limit, per_day_limit, global_cap, is_active")
      .eq("id", promo_id)
      .lte("start_at", nowIso)
      .gte("end_at", nowIso)
      .eq("is_active", true)
      .maybeSingle();
    if (perr || !promo) return new Response(JSON.stringify({ error: "PROMO_NOT_ACTIVE" }), { status: 400, headers: { "content-type": "application/json" } });

    // Forecast user/day/global caps (best-effort)
    const startOfDay = new Date(); startOfDay.setUTCHours(0,0,0,0);
    const { data: counts } = await admin.rpc("fn_promo_usage_forecast", {
      p_promo_id: promo_id,
      p_user_id: ures.user.id,
      p_day_start: startOfDay.toISOString(),
    }).single().catch(()=>({ data: null } as any));
    if (counts) {
      const u = (counts as any);
      if (promo.per_user_limit != null && u.user_total >= promo.per_user_limit) {
        return new Response(JSON.stringify({ error: "PER_USER_LIMIT" }), { status: 403, headers: { "content-type": "application/json" } });
      }
      if (promo.per_day_limit != null && u.user_day >= promo.per_day_limit) {
        return new Response(JSON.stringify({ error: "PER_DAY_LIMIT" }), { status: 403, headers: { "content-type": "application/json" } });
      }
      if (promo.global_cap != null && u.global_total >= promo.global_cap) {
        return new Response(JSON.stringify({ error: "GLOBAL_CAP" }), { status: 403, headers: { "content-type": "application/json" } });
      }
    }

    // Create nonce with TTL 75s
    const expiresAt = new Date(Date.now() + 75_000).toISOString();
    const { data: nonceRow, error: nerr } = await admin
      .from("promo_qr_nonce")
      .insert({ promo_id, user_id: ures.user.id, expires_at: expiresAt, device_hash })
      .select("nonce, expires_at")
      .single();
    if (nerr) return new Response(JSON.stringify({ error: nerr.message }), { status: 500, headers: { "content-type": "application/json" } });

    // Sign JWT per spec (HS256) with 60–90s TTL; include required claims
    const nowSec = Math.floor(Date.now() / 1000);
    const payload = {
      iss: 'truckercore.promos',
      sub: ures.user.id,
      promo_id,
      nonce: (nonceRow as any).nonce,
      location_hint,
      device_hash,
      iat: nowSec,
      exp: Math.floor((Date.now() + 75_000) / 1000),
    } as const;
    const token = await new jose.SignJWT(payload as any)
      .setProtectedHeader({ alg: 'HS256', typ: 'JWT' })
      .setIssuedAt(payload.iat)
      .setExpirationTime(payload.exp)
      .sign(new TextEncoder().encode(SECRET_PROMO_JWT_HS256));

    return new Response(JSON.stringify({ token, nonce: payload.nonce, exp: payload.exp }), { status: 200, headers: { "content-type": "application/json" } });
  } catch (e) {
    return new Response(JSON.stringify({ error: String(e) }), { status: 500, headers: { "content-type": "application/json" } });
  }
});
