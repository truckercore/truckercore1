import { NextResponse } from 'next/server';
import { createAdminClient } from '@/lib/supabase/admin';

export const dynamic = 'force-dynamic';

export async function POST(req: Request) {
  try {
    // Verify cron secret
    const authHeader = req.headers.get('authorization');
    if (authHeader !== `Bearer ${process.env.CRON_SECRET}`) {
      return NextResponse.json({ error: 'Unauthorized' }, { status: 401 });
    }

    const supabase = createAdminClient();
    const fiveMinutesAgo = new Date(Date.now() - 5 * 60 * 1000).toISOString();

    // Get latest GPS point per driver
    const { data: recentLocations } = await supabase
      .from('gps_locations')
      .select('user_id, lat, lng, speed_mph, org_id, recorded_at')
      .gte('recorded_at', fiveMinutesAgo)
      .order('recorded_at', { ascending: false });

    if (!recentLocations?.length) {
      return NextResponse.json({ ok: true, scanned: 0 });
    }

    // Dedupe — latest per driver
    const driverMap = new Map<string, typeof recentLocations[0]>();
    for (const loc of recentLocations) {
      if (!driverMap.has(loc.user_id)) driverMap.set(loc.user_id, loc);
    }

    const drivers = Array.from(driverMap.values());
    let alertCount = 0;

    for (const driver of drivers) {
      if (!driver.lat || !driver.lng) continue;

      // Check nearby hazards
      const { data: hazards } = await supabase.rpc('get_nearby_hazards', {
        lat: driver.lat,
        lng: driver.lng,
        radius_miles: 25,
      });

      const criticalHazards = (hazards || []).filter((h: any) => h.severity >= 4);
      const inspections = (hazards || []).filter((h: any) => h.type === 'inspection');

      // Check HOS from drivers table
      const { data: driverRecord } = await supabase
        .from('drivers')
        .select('hos_driving_minutes, name, id')
        .eq('user_id', driver.user_id)
        .maybeSingle();

      const hosMinutes = driverRecord?.hos_driving_minutes ?? 0;
      const hosRemaining = 660 - hosMinutes;

      // Alert: Critical hazard nearby
      if (criticalHazards.length > 0) {
        await supabase.from('notifications').insert({
          user_id: driver.user_id,
          title: '🚨 Critical hazard detected',
          body: `${criticalHazards.length} critical hazard(s) within 25 miles of your location`,
          kind: 'hazard',
          url: '/gps',
        });
        alertCount++;
      }

      // Alert: Inspection station nearby
      if (inspections.length > 0) {
        await supabase.from('notifications').insert({
          user_id: driver.user_id,
          title: '🚔 Inspection station ahead',
          body: `${inspections.length} inspection station(s) detected on your route`,
          kind: 'inspection',
          url: '/gps',
        });
        alertCount++;
      }

      // Alert: HOS warning
      if (hosRemaining <= 60 && hosRemaining > 0) {
        await supabase.from('notifications').insert({
          user_id: driver.user_id,
          title: '⏱️ HOS limit approaching',
          body: `Only ${hosRemaining} minutes of driving time remaining`,
          kind: 'hos',
          url: '/driver-dashboard',
        });
        alertCount++;
      }

      // Alert: HOS exceeded
      if (hosMinutes >= 660) {
        await supabase.from('notifications').insert({
          user_id: driver.user_id,
          title: '🛑 HOS limit exceeded',
          body: 'You have reached the 11-hour driving limit. Rest required.',
          kind: 'hos',
          url: '/driver-dashboard',
        });
        alertCount++;
      }
    }

    return NextResponse.json({
      ok: true,
      scanned: drivers.length,
      alerts: alertCount,
    });
  } catch (error) {
    return NextResponse.json(
      { error: error instanceof Error ? error.message : 'Scan failed' },
      { status: 500 }
    );
  }
}

// Also support GET for Vercel cron
export async function GET(req: Request) {
  return POST(req);
}