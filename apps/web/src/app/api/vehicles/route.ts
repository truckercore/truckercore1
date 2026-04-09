import { NextResponse } from 'next/server';
import { createClient } from '@/lib/supabase/server';

export const dynamic = 'force-dynamic';

export async function GET() {
  try {
    const supabase = await createClient();
    const { data: { user } } = await supabase.auth.getUser();
    if (!user) return NextResponse.json({ error: 'Unauthorized' }, { status: 401 });

    const { data: member } = await supabase
      .from('organization_members')
      .select('org_id')
      .eq('user_id', user.id)
      .maybeSingle();

    if (!member) return NextResponse.json({ vehicles: [] });

    const { data: vehicles, error } = await supabase
      .from('vehicles')
      .select('*')
      .eq('org_id', member.org_id)
      .eq('status', 'active')
      .order('truck_number');

    if (error) throw error;
    return NextResponse.json({ vehicles: vehicles || [] });
  } catch (error) {
    return NextResponse.json({ error: 'Failed' }, { status: 500 });
  }
}

export async function POST(req: Request) {
  try {
    const supabase = await createClient();
    const { data: { user } } = await supabase.auth.getUser();
    if (!user) return NextResponse.json({ error: 'Unauthorized' }, { status: 401 });

    const { data: member } = await supabase
      .from('organization_members')
      .select('org_id')
      .eq('user_id', user.id)
      .maybeSingle();

    if (!member) return NextResponse.json({ error: 'No org found' }, { status: 403 });

    const { truckNumber, vin, make, model, year } = await req.json();
    if (!truckNumber) return NextResponse.json({ error: 'truckNumber required' }, { status: 400 });

    const { data: vehicle, error } = await supabase
      .from('vehicles')
      .insert({
        org_id: member.org_id,
        truck_number: truckNumber,
        vin: vin ?? null,
        make: make ?? null,
        model: model ?? null,
        year: year ?? null,
      })
      .select()
      .single();

    if (error) throw error;
    return NextResponse.json({ vehicle });
  } catch (error) {
    return NextResponse.json({ error: 'Failed' }, { status: 500 });
  }
}
