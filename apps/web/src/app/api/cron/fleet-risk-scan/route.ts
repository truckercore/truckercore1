import { NextResponse } from 'next/server';
import { createAdminClient } from '@/lib/supabase/admin';
import { classifyAlert } from '@/app/api/alerts/classify/route';

export const dynamic = 'force-dynamic';

async function sendPush(baseUrl: string, userId: string, title: string, body: string, kind: string) {
  await fetch(`${baseUrl}/api/push/send`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ userId, title, body, kind, url: '/gps' }),
  }).catch(() => {});
}

export async function POST(req: Request) {
  try {
    const authHeader = req.headers.get('authorization');
    if (authHeader !== `Bearer ${process.env.CRON_SECRET}`) {
      return NextResponse.json({ error: 'Unauthorized' }, { status: 401 });
    }

    const supabase = createAdminClient();
    const baseUrl = process.env.NEXT_PUBLIC_APP_URL || 'https://truckercore12.vercel.app';
    const fiveMinutesAgo = new Date(Date.now() - 5 * 60 * 1000).toISOString();

    const { data: recentLocations } = await supabase
      .from('gps_locations')
      .select('user_id, lat, lng, speed_mph, org_id, recorded_at')
      .gte('recorded_at', fiveMinutesAgo)
      .order('recorded_at', { ascending: false });

    if (!recentLocations?.length) {
      return NextResponse.json({ ok: true, scanned: 0 });
    }

    const driverMap = new Map<string, typeof recentLocations[0]>();
    for (const loc of recentLocations) {
      if (!driverMap.has(loc.user_id)) driverMap.set(loc.user_id, loc);
    }

    const drivers = Array.from(driverMap.values());
    let alertCount = 0;

    for (const driver of drivers) {
      if (!driver.lat || !driver.lng) continue;

      // Check hazards
      const { data: hazards } = await supabase.rpc('get_nearby_hazards', {
        lat: driver.lat,
        lng: driver.lng,
        radius_miles: 25,
      });

      const criticalHazards = (hazards || []).filter((h: any) => h.severity >= 4);
      const inspections = (hazards || []).filter((h: any) => h.type === 'inspection');

      // Check HOS
      const { data: driverRecord } = await supabase
        .from('drivers')
        .select('hos_driving_minutes, name')
        .eq('user_id', driver.user_id)
        .maybeSingle();

      const hosMinutes = driverRecord?.hos_driving_minutes ?? 0;
      const hosRemaining = 660 - hosMinutes;

      // Critical hazard alert
      if (criticalHazards.length > 0) {
        const classification = classifyAlert({ type: 'hazard_nearby', severity: 4 });
        const title = '🚨 Critical hazard detected';
        const body = `${criticalHazards.length} critical hazard(s) within 25 miles`;

        await supabase.from('notifications').insert({
          user_id: driver.user_id,
          title,
          body,
          kind: 'hazard',
          url: '/gps',
        });

        await sendPush(baseUrl, driver.user_id, title, body, 'hazard');
        alertCount++;
      }

      // Inspection alert
      if (inspections.length > 0) {
        const title = '🚔 Inspection station ahead';
        const body = `${inspections.length} inspection station(s) on your route`;

        await supabase.from('notifications').insert({
          user_id: driver.user_id,
          title,
          body,
          kind: 'inspection',
          url: '/gps',
        });

        await sendPush(baseUrl, driver.user_id, title, body, 'inspection');
        alertCount++;
      }

      // HOS warning
      if (hosRemaining <= 60 && hosRemaining > 0) {
        const title = '⏱️ HOS limit approaching';
        const body = `Only ${hosRemaining} minutes of driving time remaining`;

        await supabase.from('notifications').insert({
          user_id: driver.user_id,
          title,
          body,
          kind: 'hos',
          url: '/driver-dashboard',
        });

        await sendPush(baseUrl, driver.user_id, title, body, 'hos');
        alertCount++;
      }

      // HOS exceeded
      if (hosMinutes >= 660) {
        const title = '🛑 HOS limit exceeded';
        const body = 'You have reached the 11-hour limit. Rest required.';

        await supabase.from('notifications').insert({
          user_id: driver.user_id,
          title,
          body,
          kind: 'hos',
          url: '/driver-dashboard',
        });

        await sendPush(baseUrl, driver.user_id, title, body, 'hos');
        alertCount++;
      }
    }

    return NextResponse.json({ ok: true, scanned: drivers.length, alerts: alertCount });
  } catch (error) {
    return NextResponse.json(
      { error: error instanceof Error ? error.message : 'Scan failed' },
      { status: 500 }
    );
  }
}

export async function GET(req: Request) {
  return POST(req);
}