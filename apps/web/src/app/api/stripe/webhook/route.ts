import Stripe from 'stripe';
import { headers } from 'next/headers';
import { NextResponse } from 'next/server';
import { createClient as createSupabaseAdmin } from '@supabase/supabase-js';

export const dynamic = 'force-dynamic';

const stripe = new Stripe(process.env.STRIPE_SECRET_KEY!, {
  apiVersion: '2025-03-31.basil',
});

const supabaseAdmin = createSupabaseAdmin(
  process.env.NEXT_PUBLIC_SUPABASE_URL!,
  process.env.SUPABASE_SERVICE_ROLE_KEY!,
  {
    auth: {
      persistSession: false,
      autoRefreshToken: false,
    },
  }
);

function isPremiumStatus(status: string | undefined): boolean {
  return status === 'active' || status === 'trialing';
}

async function upsertPremiumFromSubscription(subscription: Stripe.Subscription) {
  const customerId =
    typeof subscription.customer === 'string'
      ? subscription.customer
      : subscription.customer?.id;

  if (!customerId) {
    throw new Error('Subscription missing customer ID');
  }

  const planCode =
    subscription.items.data[0]?.price?.lookup_key ??
    subscription.items.data[0]?.price?.id ??
    null;

  const premium = isPremiumStatus(subscription.status);

  const { error } = await supabaseAdmin
    .from('profiles')
    .update({
      app_is_premium: premium,
      subscription_status: subscription.status,
      stripe_customer_id: customerId,
      stripe_subscription_id: subscription.id,
      plan_code: planCode,
      updated_at: new Date().toISOString(),
    })
    .eq('stripe_customer_id', customerId);

  if (error) {
    throw new Error(`Failed updating profile premium status: ${error.message}`);
  }
}

export async function POST(req: Request) {
  const body = await req.text();
  const headerStore = await headers();
  const signature = headerStore.get('stripe-signature');

  if (!signature) {
    return new NextResponse('Missing stripe-signature header', { status: 400 });
  }

  let event: Stripe.Event;

  try {
    event = stripe.webhooks.constructEvent(
      body,
      signature,
      process.env.STRIPE_WEBHOOK_SECRET!
    );
  } catch (error) {
    const message =
      error instanceof Error ? error.message : 'Webhook signature verification failed';
    return new NextResponse(message, { status: 400 });
  }

  try {
    switch (event.type) {
      case 'customer.subscription.created':
      case 'customer.subscription.updated':
      case 'customer.subscription.deleted': {
        const subscription = event.data.object as Stripe.Subscription;
        await upsertPremiumFromSubscription(subscription);
        break;
      }

      default:
        break;
    }

    return NextResponse.json({ received: true });
  } catch (error) {
    const message = error instanceof Error ? error.message : 'Webhook handler failed';
    return new NextResponse(message, { status: 500 });
  }
}
