// Supabase Edge Function: promotions.redeem (scanner portal)
// POST /functions/v1/promotions.redeem { token, cashier_id, subtotal_cents, location_id, pos_ref? }
// Verifies JWT+nonce, evaluates rules, computes discount, writes promo_redemptions with approved/declined.

import "jsr:@supabase/functions-js/edge-runtime";
import { createClient } from "npm:@supabase/supabase-js@2";
import { verifyPromoJwt } from "../_shared/verify_promo_jwt.ts";

const URL = Deno.env.get("SUPABASE_URL")!;
const ANON = Deno.env.get("SUPABASE_ANON") ?? Deno.env.get("SUPABASE_ANON_KEY");
if (!ANON) throw new Error("Missing SUPABASE_ANON (fallback SUPABASE_ANON_KEY not set)");
if (!Deno.env.get("SUPABASE_ANON") && Deno.env.get("SUPABASE_ANON_KEY")) {
  console.warn("[deprecation] SUPABASE_ANON_KEY is deprecated in Edge Functions; please set SUPABASE_ANON instead");
}
const SERVICE = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
const POS_WEBHOOK_URL = Deno.env.get("PROMO_POS_WEBHOOK_URL") ?? null;
const POS_WEBHOOK_SECRET = Deno.env.get("POS_WEBHOOK_SECRET") ?? Deno.env.get("PROMO_WEBHOOK_SECRET") ?? null;


function computeDiscount(type: string, value_cents: number, subtotal_cents: number){
  if (type === 'percent') return Math.floor((subtotal_cents * value_cents) / 10000); // value_cents as percent*100?
  return Math.min(value_cents, subtotal_cents);
}

async function sendPosWebhook(payload: any){
  if (!POS_WEBHOOK_URL || !POS_WEBHOOK_SECRET) return;
  const body = JSON.stringify(payload);
  const ts = new Date().toISOString();
  const toSign = `${ts}.${body}`;
  const key = await crypto.subtle.importKey('raw', new TextEncoder().encode(POS_WEBHOOK_SECRET), { name:'HMAC', hash:'SHA-256' }, false, ['sign']);
  const hmac = await crypto.subtle.sign({ name: 'HMAC', hash: 'SHA-256' }, key, new TextEncoder().encode(toSign));
  const hex = Array.from(new Uint8Array(hmac)).map(b=>b.toString(16).padStart(2,'0')).join('');
  const signature = `sha256=${hex}`;
  await fetch(POS_WEBHOOK_URL, {
    method: 'POST',
    headers: {
      'content-type':'application/json',
      'X-Timestamp': ts,
      'X-Signature': signature,
    },
    body
  });
}

Deno.serve(async (req) => {
  try {
    if (req.method !== 'POST') return new Response(JSON.stringify({ error: 'METHOD_NOT_ALLOWED' }), { status: 405, headers: { 'content-type': 'application/json' } });
    const auth = req.headers.get('Authorization') ?? '';
    const user = createClient(URL, ANON, { global: { headers: { Authorization: auth } } });
    const admin = createClient(URL, SERVICE);

    // Scanner must be an operator user; resolve org and location scope
    const { data: ures } = await user.auth.getUser();
    if (!ures?.user) return new Response(JSON.stringify({ error: 'AUTH_REQUIRED' }), { status: 401, headers: { 'content-type': 'application/json' } });

    // Resolve operator profile and org scope
    const { data: prof } = await user.from('profiles').select('org_id, primary_role').eq('user_id', ures.user.id).maybeSingle();
    const operatorOrgId = (prof as any)?.org_id ?? null;

    const body = await req.json().catch(()=>({} as any));

    const token = String(body.token || '');
    const cashier_id = String(body.cashier_id || '');
    const subtotal_cents = Number(body.subtotal_cents || 0);
    const location_id = String(body.location_id || '');
    const pos_ref = body.pos_ref ? String(body.pos_ref) : null;
    if (!token || !cashier_id || !location_id || !(subtotal_cents > 0)) {
      return new Response(JSON.stringify({ error: 'MISSING_FIELDS' }), { status: 400, headers: { 'content-type':'application/json' } });
    }

    // Verify operator has access to the location (must belong to same org)
    if (operatorOrgId){
      const { data: loc } = await admin.from('locations').select('location_id, org_id').eq('location_id', location_id).maybeSingle();
      if (!loc || (loc as any).org_id !== operatorOrgId) {
        return new Response(JSON.stringify({ error: 'forbidden', message: 'location not in scope' }), { status: 403, headers: { 'content-type': 'application/json' } });
      }
    }

    let claims;
    try {
      claims = verifyPromoJwt(token);
    } catch (e) {
      return new Response(JSON.stringify({ error: 'invalid_token' }), { status: 401, headers: { 'content-type':'application/json' } });
    }

    const { promo_id, sub, nonce, device_hash } = claims as any;
    const user_id = sub;
    if (!promo_id || !user_id || !nonce) return new Response(JSON.stringify({ error: 'invalid_claims' }), { status: 401, headers: { 'content-type':'application/json' } });

    // Check nonce state
    const { data: nrow } = await admin.from('promo_qr_nonce').select('nonce,expires_at,used_at,device_hash').eq('nonce', nonce).maybeSingle();
    if (!nrow) return new Response(JSON.stringify({ approved: false, reason: 'NONCE_UNKNOWN' }), { status: 400, headers: { 'content-type':'application/json' } });
    if ((nrow as any).used_at) return new Response(JSON.stringify({ error: 'conflict', message: 'nonce already used' }), { status: 409, headers: { 'content-type':'application/json' } });
    if (new Date((nrow as any).expires_at).getTime() < Date.now()) return new Response(JSON.stringify({ approved: false, reason: 'TOKEN_EXPIRED' }), { status: 400, headers: { 'content-type':'application/json' } });
    if ((nrow as any).device_hash && device_hash && (nrow as any).device_hash !== device_hash) return new Response(JSON.stringify({ approved: false, reason: 'DEVICE_MISMATCH' }), { status: 400, headers: { 'content-type':'application/json' } });

    // Load promo and enforce schedule, scope, and min spend
    const nowIso = new Date().toISOString();
    const { data: promo, error: perr } = await admin
      .from('promotions')
      .select('id, org_id, type, value_cents, start_at, end_at, min_spend_cents, global_cap, per_user_limit, per_day_limit, is_active, locations, channels, pos_shortcode')
      .eq('id', promo_id)
      .lte('start_at', nowIso)
      .gte('end_at', nowIso)
      .eq('is_active', true)
      .maybeSingle();
    if (perr || !promo) return new Response(JSON.stringify({ approved: false, reason: 'PROMO_NOT_ACTIVE' }), { status: 400, headers: { 'content-type':'application/json' } });

    if ((promo as any).min_spend_cents && subtotal_cents < (promo as any).min_spend_cents) {
      return new Response(JSON.stringify({ approved: false, reason: 'MIN_SPEND' }), { status: 200, headers: { 'content-type':'application/json' } });
    }

    // If locations scope provided, require match
    const locs = (promo as any).locations as string[] | null;
    if (Array.isArray(locs) && locs.length > 0 && !locs.includes(location_id)) {
      return new Response(JSON.stringify({ approved: false, reason: 'LOCATION_MISMATCH' }), { status: 200, headers: { 'content-type':'application/json' } });
    }

    // Velocity checks via RPC (optional)
    const startOfDay = new Date(); startOfDay.setUTCHours(0,0,0,0);
    const { data: counts } = await admin.rpc('fn_promo_usage_forecast', { p_promo_id: promo_id, p_user_id: user_id, p_day_start: startOfDay.toISOString() }).single().catch(()=>({ data: null } as any));
    if (counts){
      const u = counts as any;
      if ((promo as any).per_user_limit != null && u.user_total >= (promo as any).per_user_limit) {
        return new Response(JSON.stringify({ approved: false, reason: 'PER_USER_LIMIT' }), { status: 200, headers: { 'content-type':'application/json' } });
      }
      if ((promo as any).per_day_limit != null && u.user_day >= (promo as any).per_day_limit) {
        return new Response(JSON.stringify({ approved: false, reason: 'PER_DAY_LIMIT' }), { status: 200, headers: { 'content-type':'application/json' } });
      }
      if ((promo as any).global_cap != null && u.global_total >= (promo as any).global_cap) {
        return new Response(JSON.stringify({ approved: false, reason: 'GLOBAL_CAP' }), { status: 200, headers: { 'content-type':'application/json' } });
      }
    }

    // Compute discount
    const discount_cents = computeDiscount((promo as any).type, (promo as any).value_cents, subtotal_cents);

    // Mark nonce used (best-effort race safety)
    await admin.from('promo_qr_nonce').update({ used_at: new Date().toISOString() }).eq('nonce', nonce).is('used_at', null);

    // Insert redemption row
    const approved = discount_cents > 0;
    const ins = await admin.from('promo_redemptions').insert({
      promo_id,
      user_id,
      location_id,
      amount_cents: subtotal_cents,
      discount_cents: approved ? discount_cents : 0,
      status: approved ? 'approved' : 'declined',
      reason: approved ? null : 'NO_DISCOUNT',
      cashier_id,
      device_hash,
      pos_ref,
    } as any).select('id').single();
    if (ins.error) return new Response(JSON.stringify({ error: ins.error.message }), { status: 500, headers: { 'content-type':'application/json' } });

    const redemption_id = (ins.data as any)?.id ?? null;
    const resp: any = {
      approved,
      discount_cents: approved ? discount_cents : 0,
      pos_code: (promo as any).pos_shortcode ?? null,
      redemption_id: approved ? redemption_id : null,
      reason: approved ? null : 'NO_DISCOUNT'
    };

    // Optional webhook
    if (approved) {
      sendPosWebhook({
        event: 'promo.approved',
        redemption_id,
        org_id: (promo as any).org_id,
        location_id,
        promo_id,
        user_id,
        subtotal_cents,
        discount_cents,
        pos_code: (promo as any).pos_shortcode ?? null,
        occurred_at: new Date().toISOString(),
      }).catch(()=>{});
    }

    return new Response(JSON.stringify(resp), { status: 200, headers: { 'content-type':'application/json' } });
  } catch (e) {
    return new Response(JSON.stringify({ error: String(e) }), { status: 500, headers: { 'content-type':'application/json' } });
  }
});
