import { headers } from 'next/headers';
import { NextResponse } from 'next/server';
import { createClient as createSupabaseAdmin } from '@supabase/supabase-js';
import Stripe from 'stripe';
import {
  resolveEntitlements,
  normalizePlanCode,
  type AppRole,
} from '@/lib/billing/planAccess';

export const dynamic = 'force-dynamic';

type WebhookEventRow = {
  id: string;
  stripe_event_id: string;
  status: 'processing' | 'processed' | 'ignored' | 'failed';
  attempts: number;
};

function getStripe() {
  return new Stripe(process.env.STRIPE_SECRET_KEY!, {
    apiVersion: '2025-03-31.basil' as any,
  });
}

function getSupabaseAdmin() {
  return createSupabaseAdmin(
    process.env.NEXT_PUBLIC_SUPABASE_URL!,
    process.env.SUPABASE_SERVICE_ROLE_KEY!,
    { auth: { persistSession: false, autoRefreshToken: false } }
  );
}

async function upsertEventLock(params: {
  supabaseAdmin: ReturnType<typeof getSupabaseAdmin>;
  event: Stripe.Event;
  objectId?: string | null;
}): Promise<{ shouldProcess: boolean }> {
  const { supabaseAdmin, event, objectId } = params;

  const { data: existing } = await supabaseAdmin
    .from('stripe_webhook_events')
    .select('id, status, attempts')
    .eq('stripe_event_id', event.id)
    .maybeSingle<WebhookEventRow>();

  if (existing?.status === 'processed' || existing?.status === 'ignored') {
    return { shouldProcess: false };
  }

  if (!existing) {
    await supabaseAdmin.from('stripe_webhook_events').insert({
      stripe_event_id: event.id,
      event_type: event.type,
      livemode: event.livemode,
      object_id: objectId ?? null,
      status: 'processing',
      attempts: 1,
    });
  } else {
    await supabaseAdmin
      .from('stripe_webhook_events')
      .update({
        status: 'processing',
        attempts: existing.attempts + 1,
        updated_at: new Date().toISOString(),
      })
      .eq('stripe_event_id', event.id);
  }

  return { shouldProcess: true };
}

async function markEvent(
  supabaseAdmin: ReturnType<typeof getSupabaseAdmin>,
  stripeEventId: string,
  status: WebhookEventRow['status'],
  errorMessage?: string
) {
  await supabaseAdmin
    .from('stripe_webhook_events')
    .update({
      status,
      error_message: errorMessage ?? null,
      processed_at: ['processed', 'ignored'].includes(status)
        ? new Date().toISOString() : null,
      updated_at: new Date().toISOString(),
    })
    .eq('stripe_event_id', stripeEventId);
}

async function reconcileFromSubscription(
  supabaseAdmin: ReturnType<typeof getSupabaseAdmin>,
  subscription: Stripe.Subscription
) {
  const customerId = typeof subscription.customer === 'string'
    ? subscription.customer : subscription.customer?.id;
  if (!customerId) return;

  const planCode = normalizePlanCode(
    subscription.items.data[0]?.price?.lookup_key
    ?? subscription.items.data[0]?.price?.id
    ?? null
  );

  const { data: profile } = await supabaseAdmin
    .from('profiles')
    .select('id, role, premium_grace_until')
    .eq('stripe_customer_id', customerId)
    .maybeSingle<{ id: string; role: AppRole | null; premium_grace_until: string | null }>();

  if (!profile) return;

  const existingGrace = profile.premium_grace_until
    ? new Date(profile.premium_grace_until) : null;

  const decision = resolveEntitlements({
    status: subscription.status,
    planCode,
    currentRole: profile.role,
    existingGraceUntil: existingGrace,
  });

  await supabaseAdmin
    .from('profiles')
    .update({
      app_is_premium: decision.premium,
      is_premium: decision.premium,
      subscription_status: subscription.status,
      stripe_subscription_id: subscription.id,
      plan_code: decision.planCode,
      role: decision.role,
      premium_grace_until: decision.graceUntil?.toISOString() ?? null,
      updated_at: new Date().toISOString(),
    })
    .eq('id', profile.id);
}

async function reconcileFromCheckout(
  supabaseAdmin: ReturnType<typeof getSupabaseAdmin>,
  session: Stripe.Checkout.Session
) {
  const customerId = typeof session.customer === 'string'
    ? session.customer : session.customer?.id;
  const userId = session.client_reference_id;
  if (!customerId || !userId) return;

  const planCode = normalizePlanCode(
    (session.metadata?.plan as string | undefined) ?? null
  );
  const roleFromMetadata = (session.metadata?.role as AppRole | undefined) ?? null;

  const decision = resolveEntitlements({
    status: 'active',
    planCode,
    currentRole: roleFromMetadata,
  });

  await supabaseAdmin
    .from('profiles')
    .update({
      stripe_customer_id: customerId,
      plan_code: decision.planCode,
      role: decision.role,
      updated_at: new Date().toISOString(),
    })
    .eq('id', userId);
}

export async function POST(req: Request) {
  const stripe = getStripe();
  const supabaseAdmin = getSupabaseAdmin();

  const body = await req.text();
  const headerStore = await headers();
  const signature = headerStore.get('stripe-signature');

  if (!signature) {
    return new NextResponse('Missing stripe-signature', { status: 400 });
  }

  let event: Stripe.Event;
  try {
    event = stripe.webhooks.constructEvent(
      body, signature, process.env.STRIPE_WEBHOOK_SECRET!
    );
  } catch (err) {
    return new NextResponse(
      err instanceof Error ? err.message : 'Signature failed',
      { status: 400 }
    );
  }

  const objectId = event.data.object && 'id' in (event.data.object as object)
    ? String((event.data.object as { id?: string }).id ?? '')
    : null;

  try {
    const { shouldProcess } = await upsertEventLock({
      supabaseAdmin, event, objectId,
    });

    if (!shouldProcess) {
      return NextResponse.json({ received: true, deduped: true });
    }

    switch (event.type) {
      case 'customer.subscription.created':
      case 'customer.subscription.updated':
      case 'customer.subscription.deleted':
        await reconcileFromSubscription(
          supabaseAdmin,
          event.data.object as Stripe.Subscription
        );
        break;

      case 'checkout.session.completed':
        await reconcileFromCheckout(
          supabaseAdmin,
          event.data.object as Stripe.Checkout.Session
        );
        break;

      default:
        await markEvent(supabaseAdmin, event.id, 'ignored');
        return NextResponse.json({ received: true, ignored: true });
    }

    await markEvent(supabaseAdmin, event.id, 'processed');
    return NextResponse.json({ received: true });

  } catch (error) {
    const msg = error instanceof Error ? error.message : 'Handler failed';
    await markEvent(supabaseAdmin, event.id, 'failed', msg);
    return new NextResponse(msg, { status: 500 });
  }
}
