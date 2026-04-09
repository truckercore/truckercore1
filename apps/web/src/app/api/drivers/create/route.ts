import { NextResponse } from 'next/server';
import { createAdminClient } from '@/lib/supabase/admin';
import { createClient } from '@/lib/supabase/server';

export const dynamic = 'force-dynamic';

export async function POST(req: Request) {
  try {
    const supabase = await createClient();
    const admin = createAdminClient();

    const { data: { user } } = await supabase.auth.getUser();
    if (!user) return NextResponse.json({ error: 'Unauthorized' }, { status: 401 });

    const { name, truckNumber, phone, orgId } = await req.json();

    if (!name || !orgId) {
      return NextResponse.json({ error: 'name and orgId required' }, { status: 400 });
    }

    // Use admin client to bypass RLS for membership check
    const { data: member } = await admin
      .from('organization_members')
      .select('role')
      .eq('org_id', orgId)
      .eq('user_id', user.id)
      .maybeSingle();

    if (!member || member.role !== 'admin') {
      return NextResponse.json({ error: 'Not authorized for this org' }, { status: 403 });
    }

    const { data: driver, error } = await admin
      .from('drivers')
      .insert({
        org_id: orgId,
        name,
        truck_number: truckNumber ?? null,
        phone: phone ?? null,
        status: 'available',
        hos_driving_minutes: 0,
      })
      .select()
      .single();

    if (error) return NextResponse.json({ error: error.message }, { status: 500 });
    return NextResponse.json({ driver });
  } catch (error) {
    return NextResponse.json(
      { error: error instanceof Error ? error.message : 'Failed' },
      { status: 500 }
    );
  }
}
