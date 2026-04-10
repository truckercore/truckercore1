import { NextApiRequest, NextApiResponse } from 'next';
import { createAdminClient } from '@/lib/supabase/admin';
import Stripe from 'stripe';
import { buffer } from 'micro';

export const config = { api: { bodyParser: false } };

const PREMIUM_STATUSES = new Set(['active', 'trialing']);

export default async function handler(req: NextApiRequest, res: NextApiResponse) {
  if (req.method !== 'POST') return res.status(405).end();

  const stripe = new Stripe(process.env.STRIPE_SECRET_KEY!, { apiVersion: '2024-06-20' });
  const supabase = createAdminClient();

  const sig = req.headers['stripe-signature']!;
  const webhookSecret = process.env.STRIPE_WEBHOOK_SECRET!;
  const body = await buffer(req);

  let event: Stripe.Event;
  try {
    event = stripe.webhooks.constructEvent(body, sig, webhookSecret);
  } catch (err: any) {
    return res.status(400).json({ error: err.message });
  }

  const subscriptionEvents = new Set([
    'customer.subscription.created',
    'customer.subscription.updated',
    'customer.subscription.deleted',
  ]);

  if (subscriptionEvents.has(event.type)) {
    const subscription = event.data.object as Stripe.Subscription;
    const isPremiumStatus = (status: string) =>
      status === 'active' || status === 'trialing';

    await supabase.from('profiles').update({
      stripe_subscription_id: subscription.id,
      stripe_subscription_status: subscription.status,
      subscription_status: subscription.status,
      app_is_premium: isPremiumStatus(subscription.status),
      is_premium: isPremiumStatus(subscription.status),
      plan_code: subscription.items.data[0]?.price?.lookup_key ?? null,
      premium_expires_at: subscription.current_period_end
        ? new Date(subscription.current_period_end * 1000).toISOString()
        : null,
      updated_at: new Date().toISOString(),
    }).eq('stripe_customer_id', subscription.customer as string);
  }

  if (event.type === 'checkout.session.completed') {
    const session = event.data.object as Stripe.CheckoutSession;
    if (session.customer && session.client_reference_id) {
      await supabase
        .from('profiles')
        .update({ stripe_customer_id: session.customer as string })
        .eq('id', session.client_reference_id);
    }
  }

  res.json({ received: true });
}
