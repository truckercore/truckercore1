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

    const { driverId, userId } = await req.json();

    if (!driverId || !userId) {
      return NextResponse.json(
        { error: 'driverId and userId required' },
        { status: 400 }
      );
    }

    // Verify current user is admin of the org this driver belongs to
    const { data: driver, error: driverError } = await admin
      .from('drivers')
      .select('org_id')
      .eq('id', driverId)
      .single();

    if (driverError || !driver) {
      return NextResponse.json(
        { error: driverError?.message || 'Driver not found' },
        { status: 404 }
      );
    }

    const { data: member, error: memberError } = await admin
      .from('organization_members')
      .select('role')
      .eq('org_id', driver.org_id)
      .eq('user_id', user.id)
      .maybeSingle();

    if (memberError || !member || member.role !== 'admin') {
      return NextResponse.json(
        { error: 'Not authorized to manage this driver' },
        { status: 403 }
      );
    }

    // Link the user to the driver
    const { data: updatedDriver, error: updateError } = await admin
      .from('drivers')
      .update({ user_id: userId })
      .eq('id', driverId)
      .select()
      .single();

    if (updateError) {
      return NextResponse.json(
        { error: updateError.message },
        { status: 500 }
      );
    }

    return NextResponse.json({ driver: updatedDriver });
  } catch (error) {
    return NextResponse.json(
      { error: error instanceof Error ? error.message : 'Failed to link driver' },
      { status: 500 }
    );
  }
}
