import { NextResponse } from 'next/server';
import { createClient } from '@/lib/supabase/server';

export const dynamic = 'force-dynamic';

export async function GET(req: Request) {
  try {
    const supabase = await createClient();
    const { data: { user } } = await supabase.auth.getUser();
    if (!user) return NextResponse.json({ error: 'Unauthorized' }, { status: 401 });

    const { searchParams } = new URL(req.url);

    const { data: member } = await supabase
      .from('organization_members')
      .select('org_id')
      .eq('user_id', user.id)
      .maybeSingle();

    if (!member) return NextResponse.json({ drivers: [] });

    const { data: drivers, error } = await supabase
      .from('drivers')
      .select('*')
      .eq('org_id', member.org_id)
      .order('name');
    if (error) throw error;

    return NextResponse.json({ drivers: drivers || [] });
  } catch (error) {
    return NextResponse.json({ error: 'Failed' }, { status: 500 });
  }
}
