import { NextResponse } from 'next/server';
import { createClient } from '@/lib/supabase/server';

export const dynamic = 'force-dynamic';

export async function GET() {
  try {
    const supabase = await createClient();
    const { data: { user } } = await supabase.auth.getUser();
    if (!user) return NextResponse.json({ error: 'Unauthorized' }, { status: 401 });

    const { data: profile } = await supabase
      .from('profiles')
      .select('is_premium, app_is_premium, subscription_status, plan_code, premium_expires_at, stripe_customer_id')
      .eq('id', user.id)
      .maybeSingle();

    return NextResponse.json({
      isPremium: !!(profile?.is_premium || profile?.app_is_premium),
      subscriptionStatus: profile?.subscription_status ?? null,
      planCode: profile?.plan_code ?? null,
      premiumExpiresAt: profile?.premium_expires_at ?? null,
      stripeCustomerId: profile?.stripe_customer_id ?? null,
    });
  } catch (error) {
    return NextResponse.json({ error: 'Failed' }, { status: 500 });
  }
}