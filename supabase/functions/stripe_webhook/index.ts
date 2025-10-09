import { serve } from "https://deno.land/std@0.224.0/http/server.ts";
import Stripe from "https://esm.sh/stripe@16?target=deno";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { maybeFail } from "../_shared/fault.ts";
import { withMetrics } from "../_shared/metrics.ts";
import { ok, err, reqId } from "../_shared/http.ts";
import { logInfo, logErr } from "../_shared/obs.ts";

const STRIPE_KEY = Deno.env.get('STRIPE_SECRET_KEY') ?? Deno.env.get('STRIPE_SECRET');
const ENDPOINT_SECRET = Deno.env.get('STRIPE_WEBHOOK_SECRET')!;
const SUPABASE_URL = Deno.env.get('SUPABASE_URL')!;
const SUPABASE_SERVICE_ROLE = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!;
const stripe = new Stripe(STRIPE_KEY!, { apiVersion: '2024-06-20' });

serve((req) => withMetrics('stripe_webhook', async () => {
  const requestId = req.headers.get("X-Request-Id") ?? reqId();
  await maybeFail();
  const rawBody = await req.text();
  const sig = req.headers.get("Stripe-Signature")!;
  let evt: Stripe.Event;
  try {
    evt = stripe.webhooks.constructEvent(rawBody, sig, ENDPOINT_SECRET);
  } catch (e) {
    logErr("stripe bad signature", { requestId });
    return err("bad_request", `Webhook Error: ${(e as Error).message}`, requestId, 400);
  }

  const admin = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE);
  const eid = (evt as any).id as string;
  const type = (evt as any).type as string;

  // Idempotency guard (dedupe Stripe event id)
  // Optional off-ramp to skip processing
  if ((Deno.env.get('WEBHOOKS_DISABLED') || '').toLowerCase() === 'true') {
    await admin.from('stripe_events_dedup').insert({ event_id: eid, id: eid, type, received_at: new Date().toISOString(), status: 'skipped' }).catch(() => {});
    return new Response(JSON.stringify({ ok: true, skipped: true }), { status: 200, headers: { 'content-type': 'application/json' } });
  }

  // Idempotency guard using event_id (new schema), fallback to id
  const { data: seen, error: seenErr } = await admin
    .from('stripe_events_dedup')
    .select('event_id')
    .eq('event_id', eid)
    .maybeSingle();
  if (seen && !seenErr) {
    // Record dedup in audit trail
    try { await admin.from('stripe_webhook_audit').upsert({ id: eid, type, payload: (evt as any), status: 'dedup' }); } catch (_) {}
    return new Response(JSON.stringify({ ok: true, dedup: true }), { status: 200, headers: { 'content-type': 'application/json' } });
  }

  // Record as seen with full payload
  try { await admin.from('stripe_events_dedup').insert({ event_id: eid, id: eid, type, received_at: new Date().toISOString(), status: 'seen', payload: JSON.parse(rawBody) }); } catch (_) {}

  try {
    if (evt.type === 'checkout.session.completed') {
      const session = evt.data.object as any;
      const invoiceId = session.metadata?.invoiceId;
      if (invoiceId) {
        await admin
          .from('invoices')
          .update({
            status: 'paid',
            stripe_session_id: session.id,
            stripe_payment_intent: session.payment_intent,
          })
          .eq('id', invoiceId);
      }
      logInfo('handled checkout.session.completed', { requestId, stripe_event_id: eid });
    }

    if (evt.type === 'customer.subscription.created' || evt.type === 'customer.subscription.updated') {
      const sub = evt.data.object as Stripe.Subscription;
      const customerId = typeof sub.customer === 'string' ? sub.customer : sub.customer.id;
      const item = sub.items.data[0];
      const priceId = item?.price?.id;

      // Lookup mapping from DB (via view)
      let tier = 'basic' as 'basic' | 'premium' | 'ai';
      let mappedAi = false;
      if (priceId) {
        const { data: map } = await admin
          .from('v_price_catalog')
          .select('tier,is_ai')
          .eq('price_id', priceId)
          .single();
        if (map) { tier = map.tier as any; mappedAi = !!map.is_ai; }
      }

      // Stripe subscription status gates
      const activeStates = new Set<Stripe.Subscription.Status>(["active", "trialing"]);
      const disabledStates = new Set<Stripe.Subscription.Status>(["canceled", "unpaid", "incomplete_expired"] as any);
      const isActive = activeStates.has(sub.status);
      const disable = disabledStates.has(sub.status) || !isActive;

      const aiEnabled = !disable && mappedAi;
      let userId = (sub.metadata?.user_id as string | undefined) ?? null;

      // Resolve user_id from existing billing_profiles if missing
      if (!userId) {
        const { data: prof } = await admin.from('billing_profiles').select('user_id').eq('stripe_customer_id', customerId).maybeSingle();
        if (prof?.user_id) userId = prof.user_id;
      }

      // Grace handling for past_due / active
      const GRACE_HOURS = Number(Deno.env.get('GRACE_HOURS') ?? '168');
      const graceUntil = new Date(Date.now() + GRACE_HOURS * 3600 * 1000).toISOString();

      // Fetch current profile for grace decisions
      let currentTier: string | null = null;
      let currentAI: boolean | null = null;
      let currentGrace: string | null = null;
      if (userId) {
        const { data: cur } = await admin.from('billing_profiles').select('tier,ai_enabled,grace_until').eq('user_id', userId).maybeSingle();
        currentTier = cur?.tier ?? null; currentAI = cur?.ai_enabled ?? null; currentGrace = cur?.grace_until ?? null;
      } else {
        const { data: cur } = await admin.from('billing_profiles').select('user_id,tier,ai_enabled,grace_until').eq('stripe_customer_id', customerId).maybeSingle();
        if (cur?.user_id && !userId) userId = cur.user_id; currentTier = cur?.tier ?? null; currentAI = cur?.ai_enabled ?? null; currentGrace = cur?.grace_until ?? null;
      }

      // Apply entitlements via RPC when we have a user_id, else fall back to direct update
      const applyProfile = async (u: string, t: string, ai: boolean, g: string | null) => {
        const { error: apErr } = await admin.rpc('fn_billing_apply', { p_user_id: u, p_tier: t, p_ai_enabled: ai, p_grace_until: g });
        if (apErr) throw apErr;
      };

      if (sub.status === 'past_due' && userId) {
        if (!currentGrace) {
          await applyProfile(userId, currentTier ?? tier, currentAI ?? aiEnabled, graceUntil);
        }
      } else if (sub.status === 'active' && userId) {
        if (currentGrace) {
          await applyProfile(userId, currentTier ?? tier, currentAI ?? aiEnabled, null);
        }
      } else {
        // General apply on created/updated
        if (userId) {
          await applyProfile(userId, tier, aiEnabled, null);
        } else {
          // Fallback if we still cannot resolve user_id
          const { error } = await admin.from('billing_profiles').update({ tier, ai_enabled: aiEnabled, updated_at: new Date().toISOString(), grace_until: null }).eq('stripe_customer_id', customerId);
          if (error) throw error;
        }
      }
      logInfo('subscription upserted', { requestId, stripe_event_id: eid, sub_status: sub.status });
    }

    if (evt.type === 'customer.subscription.deleted') {
      const sub = evt.data.object as Stripe.Subscription;
      const customerId = typeof sub.customer === 'string' ? sub.customer : sub.customer.id;
      // Downgrade with grace if possible
      let userId: string | null = (sub.metadata?.user_id as string | undefined) ?? null;
      if (!userId) {
        const { data: prof } = await admin.from('billing_profiles').select('user_id').eq('stripe_customer_id', customerId).maybeSingle();
        if (prof?.user_id) userId = prof.user_id;
      }
      const GRACE_HOURS = Number(Deno.env.get('GRACE_HOURS') ?? '168');
      const graceUntil = new Date(Date.now() + GRACE_HOURS * 3600 * 1000).toISOString();
      if (userId) {
        const { error: apErr } = await admin.rpc('fn_billing_apply', { p_user_id: userId, p_tier: 'basic', p_ai_enabled: false, p_grace_until: graceUntil });
        if (apErr) throw apErr;
      } else {
        const { error } = await admin.from('billing_profiles').update({ tier: 'basic', ai_enabled: false, updated_at: new Date().toISOString(), grace_until: graceUntil }).eq('stripe_customer_id', customerId);
        if (error) throw error;
      }
      logInfo('subscription deleted: downgraded', { requestId, stripe_event_id: eid });
    }

    // Record after successful processing
    await admin.from('stripe_events_dedup').update({ processed_at: new Date().toISOString(), status: 'ok' }).eq('event_id', eid);
    // Audit: success
    try { await admin.from('stripe_webhook_audit').upsert({ id: eid, type, payload: (evt as any), status: 'success' }); } catch (_) {}
    return new Response(JSON.stringify({ ok: true }), { status: 200, headers: { 'content-type': 'application/json' } });
  } catch (e) {
    logErr('webhook handler error', { requestId, stripe_event_id: eid });
    await admin.from('stripe_events_dedup').update({ processed_at: new Date().toISOString(), status: 'error' }).eq('event_id', eid).catch(() => {});
    // Audit: error
    try { await admin.from('stripe_webhook_audit').upsert({ id: eid, type, payload: (evt as any), status: 'error', error: (e as Error).message }); } catch (_) {}
    return err('internal_error', (e as Error).message, requestId, 500);
  }
}));
