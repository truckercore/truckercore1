import { NextResponse } from 'next/server';
import { createClient } from '@/lib/supabase/server';

export const dynamic = 'force-dynamic';

export async function GET(req: Request) {
  try {
    const supabase = await createClient();
    const { data: { user } } = await supabase.auth.getUser();
    if (!user) return NextResponse.json({ error: 'Unauthorized' }, { status: 401 });

    const { searchParams } = new URL(req.url);
    const type = searchParams.get('type') || 'expenses';
    const days = Number(searchParams.get('days') || 30);
    const since = new Date(Date.now() - days * 24 * 60 * 60 * 1000)
      .toISOString().split('T')[0];

    let rows: any[] = [];
    let headers: string[] = [];

    if (type === 'expenses') {
      const { data } = await supabase
        .from('expenses')
        .select('date, category, amount, description, state, miles_driven, is_auto_logged')
        .eq('user_id', user.id)
        .gte('date', since)
        .order('date', { ascending: false });

      rows = data || [];
      headers = ['Date', 'Category', 'Amount', 'Description', 'State', 'Miles', 'Auto-Logged'];
    } else if (type === 'ifta') {
      const year = Number(searchParams.get('year') || new Date().getFullYear());
      const { data } = await supabase
        .from('ifta_mileage')
        .select('state, miles, quarter, year, fuel_purchased_gallons')
        .eq('user_id', user.id)
        .eq('year', year)
        .order('state');

      rows = data || [];
      headers = ['State', 'Miles', 'Quarter', 'Year', 'Fuel Purchased (gal)'];
    } else if (type === 'trips') {
      const { data } = await supabase
        .from('trips')
        .select('start_time, end_time, total_miles, fuel_cost, total_toll_cost, start_address, end_address')
        .eq('user_id', user.id)
        .eq('status', 'completed')
        .gte('start_time', since)
        .order('start_time', { ascending: false });

      rows = data || [];
      headers = ['Start Time', 'End Time', 'Miles', 'Fuel Cost', 'Toll Cost', 'Origin', 'Destination'];
    }

    const csvRows = [
      headers.join(','),
      ...rows.map(row =>
        Object.values(row)
          .map(v => `"${String(v ?? '').replace(/"/g, '""')}"`)
          .join(',')
      ),
    ];

    const csv = csvRows.join('\n');

    return new Response(csv, {
      headers: {
        'Content-Type': 'text/csv',
        'Content-Disposition': `attachment; filename="${type}-report-${since}.csv"`,
      },
    });
  } catch (error) {
    return NextResponse.json({ error: 'Export failed' }, { status: 500 });
  }
}
