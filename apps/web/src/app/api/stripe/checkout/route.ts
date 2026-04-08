import { NextResponse } from 'next/server';
import Stripe from 'stripe';
import { createClient } from '@/lib/supabase/server';

export const dynamic = 'force-dynamic';

const stripe = new Stripe(process.env.STRIPE_SECRET_KEY!, {
  apiVersion: '2025-02-24.acacia',
});

type AppRole =
  | 'driver'
  | 'owner_operator'
  | 'fleet_manager'
  | 'freight_broker'
  | 'admin';

type PlanKey =
  | 'driver_pro'
  | 'owner_operator_pro'
  | 'fleet_basic'
  | 'fleet_pro'
  | 'broker_pro';

const PLAN_CONFIG: Record<
  PlanKey,
  {
    envKey: string;
    roles: AppRole[];
    successPath: string;
  }
> = {
  driver_pro: {
    envKey: 'STRIPE_PRICE_DRIVER_PRO',
    roles: ['driver', 'admin'],
    successPath: '/driver-dashboard?upgraded=1',
  },
  owner_operator_pro: {
    envKey: 'STRIPE_PRICE_OWNER_OPERATOR_PRO',
    roles: ['owner_operator', 'admin'],
    successPath: '/owner-operator-dashboard?upgraded=1',
  },
  fleet_basic: {
    envKey: 'STRIPE_PRICE_FLEET_BASIC',
    roles: ['fleet_manager', 'admin'],
    successPath: '/fleet-manager-dashboard?upgraded=1',
  },
  fleet_pro: {
    envKey: 'STRIPE_PRICE_FLEET_PRO',
    roles: ['fleet_manager', 'admin'],
    successPath: '/fleet-manager-dashboard?upgraded=1',
  },
  broker_pro: {
    envKey: 'STRIPE_PRICE_BROKER_PRO',
    roles: ['freight_broker', 'admin'],
    successPath: '/freight-broker-dashboard?upgraded=1',
  },
};

function getBaseUrl(request: Request) {
  const url = new URL(request.url);
  return `${url.protocol}//${url.host}`;
}

function isAllowedRole(role: string | null | undefined, allowed: AppRole[]) {
  if (!role) return false;
  if (role === 'admin') return true;
  return allowed.includes(role as AppRole);
}

export async function GET(request: Request) {
  try {
    const url = new URL(request.url);
    const plan = url.searchParams.get('plan') as PlanKey | null;
    const from = url.searchParams.get('from') || '/upgrade';

    if (!plan || !(plan in PLAN_CONFIG)) {
      return NextResponse.json({ error: 'Invalid or missing plan' }, { status: 400 });
    }

    const supabase = await createClient();

    const {
      data: { user },
    } = await supabase.auth.getUser();

    if (!user) {
      const loginUrl = new URL('/login', request.url);
      loginUrl.searchParams.set('redirectTo', `/upgrade?from=${encodeURIComponent(from)}`);
      return NextResponse.redirect(loginUrl);
    }

    const { data: profile, error: profileError } = await supabase
      .from('profiles')
      .select('role, stripe_customer_id, full_name')
      .eq('id', user.id)
      .maybeSingle();

    if (profileError) {
      return NextResponse.json(
        { error: `Failed to load profile: ${profileError.message}` },
        { status: 500 }
      );
    }

    const config = PLAN_CONFIG[plan];

    if (!isAllowedRole(profile?.role, config.roles)) {
      return NextResponse.json(
        { error: 'This plan is not available for your role' },
        { status: 403 }
      );
    }

    const priceId = process.env[config.envKey];
    if (!priceId) {
      return NextResponse.json(
        { error: `Missing environment variable ${config.envKey}` },
        { status: 500 }
      );
    }

    const baseUrl = getBaseUrl(request);

    const successUrl = `${baseUrl}${config.successPath}`;
    const cancelUrl = `${baseUrl}/upgrade?from=${encodeURIComponent(from)}&canceled=1`;

    const session = await stripe.checkout.sessions.create({
      mode: 'subscription',
      line_items: [
        {
          price: priceId,
          quantity: 1,
        },
      ],
      success_url: successUrl,
      cancel_url: cancelUrl,
      customer: profile?.stripe_customer_id || undefined,
      customer_email: profile?.stripe_customer_id ? undefined : user.email,
      client_reference_id: user.id,
      metadata: {
        user_id: user.id,
        role: profile?.role ?? '',
        plan,
        from,
      },
      subscription_data: {
        metadata: {
          user_id: user.id,
          role: profile?.role ?? '',
          plan,
        },
      },
      allow_promotion_codes: true,
    });

    return NextResponse.redirect(session.url!, { status: 303 });
  } catch (error) {
    const message = error instanceof Error ? error.message : 'Checkout creation failed';
    return NextResponse.json({ error: message }, { status: 500 });
  }
}