import { NextResponse } from 'next/server';
import { createClient } from '@/lib/supabase/server';

export const dynamic = 'force-dynamic';

export async function POST(req: Request) {
  try {
    const supabase = await createClient();
    const { data: { user } } = await supabase.auth.getUser();
    if (!user) return NextResponse.json({ error: 'Unauthorized' }, { status: 401 });

    const { name, truckNumber, phone, licenseNumber, orgId } = await req.json();

    if (!name || !orgId) {
      return NextResponse.json({ error: 'name and orgId required' }, { status: 400 });
    }

    // Verify user is admin of this org
    const { data: member } = await supabase
      .from('organization_members')
      .select('role')
      .eq('org_id', orgId)
      .eq('user_id', user.id)
      .maybeSingle();

    if (!member || member.role !== 'admin') {
      return NextResponse.json({ error: 'Not authorized for this org' }, { status: 403 });
    }

    const { data: driver, error } = await supabase
      .from('drivers')
      .insert({
        org_id: orgId,
        name,
        truck_number: truckNumber ?? null,
        phone: phone ?? null,
        license_number: licenseNumber ?? null,
        status: 'available',
      })
      .select()
      .single();

    if (error) throw error;
    return NextResponse.json({ driver });
  } catch (error) {
    return NextResponse.json(
      { error: error instanceof Error ? error.message : 'Failed' },
      { status: 500 }
    );
  }
}
