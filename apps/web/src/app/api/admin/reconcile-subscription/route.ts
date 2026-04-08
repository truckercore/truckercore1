import { NextResponse } from 'next/server';
import Stripe from 'stripe';
import { createClient as createSupabaseAdmin } from '@supabase/supabase-js';
import { resolveEntitlements, normalizePlanCode, type AppRole } from '@/lib/billing/planAccess';

export const dynamic = 'force-dynamic';

export async function POST(req: Request) {
  try {
    const stripe = new Stripe(process.env.STRIPE_SECRET_KEY!, {
      apiVersion: '2025-03-31.basil' as any,
    });
    const supabaseAdmin = createSupabaseAdmin(
      process.env.NEXT_PUBLIC_SUPABASE_URL!,
      process.env.SUPABASE_SERVICE_ROLE_KEY!,
      { auth: { persistSession: false, autoRefreshToken: false } }
    );

    const { stripeCustomerId } = await req.json() as { stripeCustomerId?: string };
    if (!stripeCustomerId) {
      return NextResponse.json({ error: 'stripeCustomerId required' }, { status: 400 });
    }

    const subscriptions = await stripe.subscriptions.list({
      customer: stripeCustomerId,
      limit: 10,
      status: 'all',
    });

    const best = subscriptions.data[0];
    if (!best) {
      return NextResponse.json({ error: 'No subscription found' }, { status: 404 });
    }

    const planCode = normalizePlanCode(
      best.items.data[0]?.price?.lookup_key
      ?? best.items.data[0]?.price?.id
      ?? null
    );

    const { data: profile } = await supabaseAdmin
      .from('profiles')
      .select('id, role, premium_grace_until')
      .eq('stripe_customer_id', stripeCustomerId)
      .maybeSingle<{ id: string; role: AppRole | null; premium_grace_until: string | null }>();

    if (!profile) {
      return NextResponse.json({ error: 'Profile not found' }, { status: 404 });
    }

    const existingGrace = profile.premium_grace_until
      ? new Date(profile.premium_grace_until) : null;

    const decision = resolveEntitlements({
      status: best.status,
      planCode,
      currentRole: profile.role,
      existingGraceUntil: existingGrace,
    });

    await supabaseAdmin
      .from('profiles')
      .update({
        app_is_premium: decision.premium,
        is_premium: decision.premium,
        subscription_status: best.status,
        stripe_subscription_id: best.id,
        plan_code: decision.planCode,
        role: decision.role,
        premium_grace_until: decision.graceUntil?.toISOString() ?? null,
        updated_at: new Date().toISOString(),
      })
      .eq('id', profile.id);

    return NextResponse.json({
      ok: true,
      status: best.status,
      premium: decision.premium,
      isGrace: decision.isGrace,
      graceUntil: decision.graceUntil?.toISOString() ?? null,
      role: decision.role,
      planCode: decision.planCode,
    });

  } catch (error) {
    return NextResponse.json(
      { error: error instanceof Error ? error.message : 'Failed' },
      { status: 500 }
    );
  }
}
