// scripts/seed_demo.mjs
// Seed 90 days of demo data for sales demos
import { createClient } from '@supabase/supabase-js';
import { randomUUID } from 'crypto';

const SUPABASE_URL = process.env.SUPABASE_URL || process.env.NEXT_PUBLIC_SUPABASE_URL;
const SERVICE_KEY = process.env.SUPABASE_SERVICE_ROLE_KEY || process.env.SUPABASE_SERVICE_ROLE;

if (!SUPABASE_URL || !SERVICE_KEY) {
  console.error('Missing Supabase config');
  process.exit(1);
}

const supabase = createClient(SUPABASE_URL, SERVICE_KEY, { auth: { persistSession: false } });

const DEMO_ORG_ID = process.env.DEMO_ORG_ID || randomUUID();
const DAYS = 90;
const ALERTS_PER_DAY = 12;
const DRIVERS = 8;

async function main() {
  console.log(`[seed:demo] Seeding org ${DEMO_ORG_ID} with ${DAYS} days...`);

  const driverIds = Array.from({ length: DRIVERS }, () => randomUUID());
  const eventTypes = ['ACCIDENT', 'CONSTRUCTION', 'WEATHER', 'LOW_BRIDGE', 'SPEED_TRAP'];
  const severities = ['INFO', 'WARN', 'URGENT'];

  // Create demo drivers
  for (let i = 0; i < driverIds.length; i++) {
    const driverId = driverIds[i];
    await supabase.from('driver_profiles').upsert({
      user_id: driverId,
      org_id: DEMO_ORG_ID,
      display_name: `Demo Driver ${i + 1}`,
      trust_score: 0.5 + Math.random() * 0.4,
      is_demo: true,
    });
  }

  // Generate alerts
  const alerts = [];
  for (let d = 0; d < DAYS; d++) {
    const date = new Date();
    date.setDate(date.getDate() - d);

    for (let i = 0; i < ALERTS_PER_DAY; i++) {
      const driverId = driverIds[Math.floor(Math.random() * driverIds.length)];
      const eventType = eventTypes[Math.floor(Math.random() * eventTypes.length)];
      const severity = severities[Math.floor(Math.random() * severities.length)];

      alerts.push({
        id: randomUUID(),
        org_id: DEMO_ORG_ID,
        user_id: driverId,
        source: 'demo',
        event_type: eventType,
        title: `Demo ${eventType}`,
        message: `Sample alert for demo purposes`,
        severity,
        geom: `POINT(${-95 + Math.random() * 10} ${35 + Math.random() * 10})`,
        created_at: date.toISOString(),
      });
    }
  }

  console.log(`[seed:demo] Inserting ${alerts.length} alerts...`);
  const { error: alertErr } = await supabase.from('alert_events').insert(alerts);
  if (alertErr) throw alertErr;

  // Seed expenses (optional categories for owner-operators)
  const expenses = [];
  for (let d = 0; d < DAYS; d++) {
    const date = new Date();
    date.setDate(date.getDate() - d);
    for (let i = 0; i < 3; i++) {
      expenses.push({
        id: randomUUID(),
        org_id: DEMO_ORG_ID,
        user_id: driverIds[Math.floor(Math.random() * driverIds.length)],
        category: ['fuel', 'tolls', 'repairs'][Math.floor(Math.random() * 3)],
        amount_usd: Number((50 + Math.random() * 200).toFixed(2)),
        incurred_on: date.toISOString().slice(0, 10),
      });
    }
  }

  console.log(`[seed:demo] Inserting ${expenses.length} expenses...`);
  await supabase.from('ownerop_expenses').insert(expenses).catch(() => {});

  // Refresh safety summaries if RPC exists
  console.log('[seed:demo] Refreshing safety summaries (best-effort)...');
  await supabase.rpc('refresh_safety_summary', { p_org: DEMO_ORG_ID, p_days: DAYS }).catch(() => {});

  console.log(`✅ Demo org ${DEMO_ORG_ID} seeded successfully.`);
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});