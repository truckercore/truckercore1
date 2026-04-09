import { NextResponse } from 'next/server';
import { createClient } from '@/lib/supabase/server';

export const dynamic = 'force-dynamic';

export async function POST(req: Request) {
  try {
    const supabase = await createClient();
    const { data: { user } } = await supabase.auth.getUser();
    if (!user) return NextResponse.json({ error: 'Unauthorized' }, { status: 401 });

    const { orgName } = await req.json();

    // Check if user already has an org
    const { data: existing } = await supabase
      .from('organization_members')
      .select('org_id')
      .eq('user_id', user.id)
      .eq('role', 'admin')
      .maybeSingle();

    if (existing) {
      return NextResponse.json({ orgId: existing.org_id, existing: true });
    }

    // Create org
    const { data: org, error: orgError } = await supabase
      .from('organizations')
      .insert({
        name: orgName || `${user.email}'s Fleet`,
        owner_id: user.id,
      })
      .select()
      .single();

    if (orgError) throw orgError;

    // Add as admin
    await supabase.from('organization_members').insert({
      org_id: org.id,
      user_id: user.id,
      role: 'admin',
    });

    // Update profile with org
    await supabase
      .from('profiles')
      .update({ role: 'fleet_manager' })
      .eq('id', user.id);

    return NextResponse.json({ orgId: org.id, org });
  } catch (error) {
    return NextResponse.json(
      { error: error instanceof Error ? error.message : 'Org setup failed' },
      { status: 500 }
    );
  }
}
