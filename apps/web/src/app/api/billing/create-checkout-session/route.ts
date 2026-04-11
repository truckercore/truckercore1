import { NextRequest, NextResponse } from 'next/server';
import { getAuthenticatedUser } from '@/lib/auth/getAuthenticatedUser';

// Stripe initialization placeholder
// const stripe = new Stripe(process.env.STRIPE_SECRET_KEY!, { apiVersion: '2023-10-16' });

export async function POST(req: NextRequest) {
  try {
    const { user } = await getAuthenticatedUser('/pricing');
    const { priceId } = await req.json();

    if (!priceId) {
      return NextResponse.json({ error: 'Missing parameters' }, { status: 400 });
    }

    // In a real scenario, we'd use stripe.checkout.sessions.create
    // For now, we return a mock URL
    console.log('Creating checkout session for user', user.id, 'with price', priceId);

    const sessionUrl = `/api/billing/mock-success?userId=${user.id}&priceId=${priceId}`;

    return NextResponse.json({ url: sessionUrl });
  } catch (err: any) {
    return NextResponse.json({ error: err.message }, { status: 500 });
  }
}
