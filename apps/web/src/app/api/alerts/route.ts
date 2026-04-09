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
    const since = new Date(Date.now() - 24 * 60 * 60 * 1000).toISOString();

    const [{ data: geofenceEvents }, { data: notifications }] = await Promise.all([
      supabase
        .from('geofence_events')
        .select('*')
        .eq('user_id', user.id)
        .gte('created_at', since)
        .order('created_at', { ascending: false })
        .limit(limit),
      supabase
        .from('notifications')
        .select('*')
        .eq('user_id', user.id)
        .gte('created_at', since)
        .order('created_at', { ascending: false })
        .limit(limit),
    ]);

    // Merge and sort by time
    const events = [
      ...(geofenceEvents || []).map(e => ({
        id: e.id,
        type: 'geofence',
        title: `📍 ${e.geofence_name || 'Geofence'} entered`,
        body: e.event_type,
        created_at: e.created_at,
        severity: 'info',
      })),
      ...(notifications || []).map(n => ({
        id: n.id,
        type: n.kind || 'notification',
        title: n.title,
        body: n.body,
        created_at: n.created_at,
        severity: n.kind === 'reroute' ? 'warning' : 'info',
        url: n.url,
      })),
    ].sort((a, b) =>
      new Date(b.created_at).getTime() - new Date(a.created_at).getTime()
    ).slice(0, limit);

    return NextResponse.json({ events, count: events.length });
  } catch (error) {
    return NextResponse.json({ error: 'Failed' }, { status: 500 });
  }
}
