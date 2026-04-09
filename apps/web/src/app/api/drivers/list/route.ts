import { NextResponse } from 'next/server';
import { createClient } from '@/lib/supabase/server';

export const dynamic = 'force-dynamic';

export async function GET(req: Request) {
  try {
    const supabase = await createClient();
    const { data: { user } } = await supabase.auth.getUser();
    if (!user) return NextResponse.json({ error: 'Unauthorized' }, { status: 401 });

    const { searchParams } = new URL(req.url);
    const orgId = searchParams.get('orgId');

    let query = supabase
      .from('drivers')
      .select('*')
      .order('name');

    if (orgId) query = query.eq('org_id', orgId);

    const { data: drivers, error } = await query;
    if (error) throw error;

    return NextResponse.json({ drivers: drivers || [] });
  } catch (error) {
    return NextResponse.json({ error: 'Failed' }, { status: 500 });
  }
}
