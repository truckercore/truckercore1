import type { NextApiRequest, NextApiResponse } from 'next';
import Stripe from 'stripe';
import { buffer } from 'micro';
import { createClient } from '@supabase/supabase-js';

export const config = { api: { bodyParser: false } };

const stripe = new Stripe(process.env.STRIPE_SECRET_KEY!, { apiVersion: '2023-10-16' });
const WEBHOOK_SECRET = process.env.STRIPE_WEBHOOK_SECRET!;
const SUPABASE_URL = process.env.NEXT_PUBLIC_SUPABASE_URL!;
const SERVICE_KEY = process.env.SUPABASE_SERVICE_ROLE_KEY!;

const supabase = createClient(SUPABASE_URL, SERVICE_KEY);

export default async function handler(req: NextApiRequest, res: NextApiResponse) {
  if (req.method !== 'POST') return res.status(405).send('Method not allowed');

  try {
    const buf = await buffer(req);
    const sig = req.headers['stripe-signature'] as string;
    const event = stripe.webhooks.constructEvent(buf, sig, WEBHOOK_SECRET);

    switch (event.type) {
      case 'checkout.session.completed': {
        const session = event.data.object as Stripe.Checkout.Session;
        const customerId = session.customer as string;
        const subId = session.subscription as string;
        const orgId = session.metadata?.org_id as string | undefined;
        const referrerCode = session.metadata?.referrer_code as string | undefined;

        if (orgId) {
          await supabase.from('stripe_customers').upsert({
            id: customerId,
            org_id: orgId,
            email: (session.customer_email as string) || null,
            name: session.customer_details?.name || null,
            metadata: session.metadata || {},
            updated_at: new Date().toISOString(),
          });

          if (referrerCode) {
            await supabase.from('referrals').insert({
              referrer_code: referrerCode,
              referred_org_id: orgId,
              stripe_customer_id: customerId,
              utm_source: session.metadata?.utm_source || null,
              utm_campaign: session.metadata?.utm_campaign || null,
            } as any).select().single().catch(() => null);
          }

          await supabase.from('metrics_events').insert({
            kind: 'stripe_checkout_completed',
            labels: { plan: session.metadata?.plan || 'unknown' },
            props: { session_id: session.id, customer_id: customerId, org_id: orgId },
          } as any).catch(() => null);
        }

        if (subId) {
          const sub = await stripe.subscriptions.retrieve(subId);
          await upsertSubscription(sub);
        }
        break;
      }

      case 'customer.subscription.created':
      case 'customer.subscription.updated': {
        const sub = event.data.object as Stripe.Subscription;
        await upsertSubscription(sub);
        break;
      }

      case 'customer.subscription.deleted': {
        const sub = event.data.object as Stripe.Subscription;
        await supabase.from('stripe_subscriptions').update({
          status: 'canceled',
          canceled_at: sub.canceled_at ? new Date(sub.canceled_at * 1000).toISOString() : new Date().toISOString(),
          updated_at: new Date().toISOString(),
        }).eq('id', sub.id);

        await supabase.from('metrics_events').insert({
          kind: 'stripe_subscription_canceled',
          labels: { plan: sub.items.data[0]?.price?.metadata?.plan || 'unknown' },
          props: { subscription_id: sub.id },
        } as any).catch(() => null);
        break;
      }

      default:
        console.log(`[stripe-webhook] Unhandled event type: ${event.type}`);
    }

    res.status(200).json({ received: true });
  } catch (e: any) {
    console.error('[stripe-webhook] Error:', e);
    res.status(400).send(`Webhook Error: ${e.message}`);
  }
}

async function upsertSubscription(sub: Stripe.Subscription) {
  const customerId = sub.customer as string;
  const { data: customerRow } = await supabase
    .from('stripe_customers')
    .select('org_id')
    .eq('id', customerId)
    .single();

  const orgId = customerRow?.org_id as string | undefined;
  if (!orgId) {
    console.warn(`[stripe-webhook] No org mapping for customer ${customerId}`);
  }

  await supabase.from('stripe_subscriptions').upsert({
    id: sub.id,
    org_id: orgId || null,
    customer_id: customerId,
    price_id: sub.items.data[0]?.price?.id || '',
    status: sub.status,
    current_period_start: new Date(sub.current_period_start * 1000).toISOString(),
    current_period_end: new Date(sub.current_period_end * 1000).toISOString(),
    cancel_at_period_end: sub.cancel_at_period_end || false,
    canceled_at: sub.canceled_at ? new Date(sub.canceled_at * 1000).toISOString() : null,
    trial_end: sub.trial_end ? new Date(sub.trial_end * 1000).toISOString() : null,
    metadata: sub.metadata || {},
    updated_at: new Date().toISOString(),
  } as any);

  const plan = sub.items.data[0]?.price?.metadata?.plan || 'pro';
  const isPremium = sub.status === 'active' || sub.status === 'trialing';
  if (orgId) {
    await supabase.rpc('update_org_premium_flag', {
      p_org_id: orgId,
      p_premium: isPremium,
      p_plan: plan,
    }).catch(() => null);
  }

  await supabase.from('metrics_events').insert({
    kind: 'stripe_subscription_updated',
    labels: { plan, status: sub.status },
    props: { subscription_id: sub.id, org_id: orgId },
  } as any).catch(() => null);
}
