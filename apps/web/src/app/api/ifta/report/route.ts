import { NextResponse } from 'next/server';
import { createClient } from '@/lib/supabase/server';

export const dynamic = 'force-dynamic';

export async function GET(req: Request) {
  try {
    const supabase = await createClient();
    const { data: { user } } = await supabase.auth.getUser();
    if (!user) return NextResponse.json({ error: 'Unauthorized' }, { status: 401 });

    const { searchParams } = new URL(req.url);
    const year = Number(searchParams.get('year') || new Date().getFullYear());
    const quarter = searchParams.get('quarter'); // optional filter

    let query = supabase
      .from('ifta_mileage')
      .select('*')
      .eq('user_id', user.id)
      .eq('year', year);

    if (quarter) query = query.eq('quarter', quarter);

    const { data: mileage } = await query;

    // Group by state
    const byState = new Map<string, { miles: number; fuel: number }>();
    for (const row of mileage || []) {
      const existing = byState.get(row.state) || { miles: 0, fuel: 0 };
      byState.set(row.state, {
        miles: existing.miles + row.miles,
        fuel: existing.fuel + (row.fuel_purchased_gallons || 0),
      });
    }

    const stateBreakdown = Array.from(byState.entries())
      .map(([state, data]) => ({
        state,
        miles: Math.round(data.miles * 10) / 10,
        fuelPurchased: Math.round(data.fuel * 100) / 100,
      }))
      .sort((a, b) => b.miles - a.miles);

    const totalMiles = stateBreakdown.reduce((sum, s) => sum + s.miles, 0);

    return NextResponse.json({
      year,
      quarter: quarter || 'all',
      totalMiles: Math.round(totalMiles * 10) / 10,
      stateBreakdown,
      reportReady: stateBreakdown.length > 0,
    });
  } catch (error) {
    return NextResponse.json(
      { error: error instanceof Error ? error.message : 'Failed to generate IFTA report' },
      { status: 500 }
    );
  }
}
