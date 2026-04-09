import { NextResponse } from 'next/server';
import { createAdminClient } from '@/lib/supabase/admin';
import { createClient } from '@/lib/supabase/server';

export const dynamic = 'force-dynamic';

export async function POST(req: Request) {
  try {
    const supabase = await createClient();
    const admin = createAdminClient();

    const {
      data: { user },
      error: authError,
    } = await supabase.auth.getUser();

    if (authError || !user) {
      return NextResponse.json(
        { error: authError?.message || 'Unauthorized' },
        { status: 401 }
      );
    }

    const body = await req.json();
    const {
      name,
      truckNumber,
      phone,
      licenseNumber,
      orgId,
    } = body as {
      name?: string;
      truckNumber?: string;
      phone?: string;
      licenseNumber?: string;
      orgId?: string;
    };

    if (!name || !orgId) {
      return NextResponse.json(
        { error: 'name and orgId required' },
        { status: 400 }
      );
    }

    // Use admin client to bypass RLS for membership check
    const { data: member, error: memberError } = await admin
      .from('organization_members')
      .select('role')
      .eq('org_id', orgId)
      .eq('user_id', user.id)
      .maybeSingle();

    if (memberError) {
      console.error('organization_members lookup failed', memberError);
      return NextResponse.json(
        { error: memberError.message },
        { status: 500 }
      );
    }

    if (!member || member.role !== 'admin') {
      return NextResponse.json(
        { error: 'Not authorized for this org' },
        { status: 403 }
      );
    }

    const insertPayload = {
      org_id: orgId,
      name,
      truck_number: truckNumber ?? null,
      phone: phone ?? null,
      license_number: licenseNumber ?? null,
      status: 'available',
    };

    console.log('Creating placeholder driver with payload:', insertPayload);

    const { data: driver, error: insertError } = await admin
      .from('drivers')
      .insert(insertPayload)
      .select()
      .single();

    if (insertError) {
      console.error('drivers insert failed', insertError);
      return NextResponse.json(
        { error: insertError.message, details: insertError },
        { status: 500 }
      );
    }

    return NextResponse.json({ driver });
  } catch (error) {
    console.error('CREATE DRIVER CRASH:', error);
    return NextResponse.json(
      {
        error: error instanceof Error ? error.message : 'Failed to create driver',
      },
      { status: 500 }
    );
  }
}
