import { NextResponse } from 'next/server';
import { createClient } from '@/lib/supabase/server';

export const dynamic = 'force-dynamic';

export async function GET(req: Request) {
  try {
    const supabase = await createClient();
    const { data: { user } } = await supabase.auth.getUser();
    if (!user) return NextResponse.json({ error: 'Unauthorized' }, { status: 401 });

    const { searchParams } = new URL(req.url);
    const limit = Number(searchParams.get('limit') || 20);
    const days = Number(searchParams.get('days') || 30);
    const since = new Date(Date.now() - days * 24 * 60 * 60 * 1000).toISOString();

    const { data: trips } = await supabase
      .from('trips')
      .select('*')
      .eq('user_id', user.id)
      .eq('status', 'completed')
      .gte('created_at', since)
      .order('created_at', { ascending: false })
      .limit(limit);

    const { data: expenses } = await supabase
      .from('expenses')
      .select('*')
      .eq('user_id', user.id)
      .gte('date', since.split('T')[0])
      .order('date', { ascending: false });

    // Aggregate totals
    const totalMiles = (trips || []).reduce((sum, t) => sum + (t.total_miles || 0), 0);
    const totalFuel = (expenses || [])
      .filter(e => e.category === 'fuel')
      .reduce((sum, e) => sum + e.amount, 0);
    const totalTolls = (expenses || [])
      .filter(e => e.category === 'toll')
      .reduce((sum, e) => sum + e.amount, 0);

    return NextResponse.json({
      trips: trips || [],
      expenses: expenses || [],
      summary: {
        totalTrips: trips?.length || 0,
        totalMiles: Math.round(totalMiles * 10) / 10,
        totalFuelCost: Math.round(totalFuel * 100) / 100,
        totalTollCost: Math.round(totalTolls * 100) / 100,
        totalExpenses: Math.round((totalFuel + totalTolls) * 100) / 100,
      },
    });
  } catch (error) {
    return NextResponse.json(
      { error: error instanceof Error ? error.message : 'Failed to load history' },
      { status: 500 }
    );
  }
}
