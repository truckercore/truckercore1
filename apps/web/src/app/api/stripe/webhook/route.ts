import { headers } from 'next/headers';
import { NextResponse } from 'next/server';
import { createClient as createSupabaseAdmin } from '@supabase/supabase-js';
import Stripe from 'stripe';

export const dynamic = 'force-dynamic';

function isPremiumStatus(status: string | undefined): boolean {
  return status === 'active' || status === 'trialing';
}

export async function POST(req: Request) {
  const stripe = new Stripe(process.env.STRIPE_SECRET_KEY!, {
    apiVersion: '2025-03-31.basil' as any,
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

  const body = await req.text();
  const headerStore = await headers();
  const signature = headerStore.get('stripe-signature');

  if (!signature) {
    return new NextResponse('Missing stripe-signature', { status: 400 });
  }

  let event: Stripe.Event;

  try {
    event = stripe.webhooks.constructEvent(
      body,
      signature,
      process.env.STRIPE_WEBHOOK_SECRET!
    );
  } catch (error) {
    const msg =
      error instanceof Error ? error.message : 'Signature verification failed';
    return new NextResponse(msg, { status: 400 });
  }

  try {
    switch (event.type) {
      case 'customer.subscription.created':
      case 'customer.subscription.updated':
      case 'customer.subscription.deleted': {
        const subscription = event.data.object as Stripe.Subscription;

        const customerId =
          typeof subscription.customer === 'string'
            ? subscription.customer
            : subscription.customer?.id;

        if (!customerId) break;

        const planCode =
          subscription.items.data[0]?.price?.lookup_key ??
          subscription.items.data[0]?.price?.id ??
          null;

        const premium = isPremiumStatus(subscription.status);

        await supabaseAdmin
          .from('profiles')
          .update({
            app_is_premium: premium,
            is_premium: premium,
            subscription_status: subscription.status,
            stripe_subscription_id: subscription.id,
            plan_code: planCode,
            updated_at: new Date().toISOString(),
          })
          .eq('stripe_customer_id', customerId);

        break;
      }

      case 'checkout.session.completed': {
        const session = event.data.object as Stripe.CheckoutSession;

        if (session.customer && session.client_reference_id) {
          await supabaseAdmin
            .from('profiles')
            .update({
              stripe_customer_id: session.customer as string,
            })
            .eq('id', session.client_reference_id);
        }

        break;
      }
    }

    return NextResponse.json({ received: true });
  } catch (error) {
    const msg = error instanceof Error ? error.message : 'Handler failed';
    return new NextResponse(msg, { status: 500 });
  }
}
