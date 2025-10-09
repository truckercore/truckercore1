import type { NextRequest } from 'next/server';
import { createClient } from '@supabase/supabase-js';

const supabase = createClient(
  process.env.NEXT_PUBLIC_SUPABASE_URL!,
  process.env.SUPABASE_SERVICE_ROLE_KEY!
);

export async function POST(req: NextRequest) {
  try {
    const { orgId, userId, fleetSize, annualMiles } = await req.json();
    if (!orgId || !userId || typeof fleetSize !== 'number' || typeof annualMiles !== 'number') {
      return new Response(JSON.stringify({ error: 'Missing fields' }), { status: 400 });
    }

    // Stub quote calculation
    const basePremium = 1200;
    const premiumUsd = basePremium * fleetSize * (1 + annualMiles / 1_000_000);

    const quoteData = {
      fleetSize,
      annualMiles,
      coverage: 'General Liability + Auto Liability',
      provider: 'Next Insurance',
    };

    const { data, error } = await supabase.from('insurance_quotes')
      .insert({
        org_id: orgId,
        user_id: userId,
        provider: 'next_insurance',
        quote_data: quoteData as any,
        premium_usd: premiumUsd,
        status: 'quoted',
      })
      .select()
      .single();

    if (error) {
      return new Response(JSON.stringify({ error: error.message }), { status: 500 });
    }

    return new Response(JSON.stringify({ quote: data }), { status: 200, headers: { 'content-type': 'application/json' } });
  } catch (e: any) {
    console.error('[insurance/quote]', e);
    return new Response(JSON.stringify({ error: e.message || 'Server error' }), { status: 500 });
  }
}
