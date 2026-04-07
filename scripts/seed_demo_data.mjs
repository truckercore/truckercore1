import { createClient } from "@supabase/supabase-js";

const SUPABASE_URL = process.env.NEXT_PUBLIC_SUPABASE_URL || process.env.SUPABASE_URL;
const SERVICE_KEY = process.env.SUPABASE_SERVICE_ROLE_KEY || process.env.SUPABASE_SERVICE_ROLE;

if (!SUPABASE_URL || !SERVICE_KEY) {
  console.error("Missing Supabase config");
  process.exit(1);
}

const supabase = createClient(SUPABASE_URL, SERVICE_KEY, { auth: { persistSession: false } });

async function seed() {
  const demoOrgId = process.env.DEMO_ORG_ID || "00000000-0000-0000-0000-000000000001";
  const demoUserId = "00000000-0000-0000-0000-000000000002";
  const DAYS = 90;
  const ALERTS_PER_DAY = 12;

  // Org
  await supabase.from("organizations").upsert({
    id: demoOrgId,
    name: "Demo Freight Inc",
    plan: "pro",
    premium: true,
    admin_email: "demo@truckercore.com",
  });

  // Alert events (last 90 days, ~12/day)
  const events = [];
  const types = ["ACCIDENT", "CONSTRUCTION", "WEATHER", "LOW_BRIDGE", "HAZMAT_RESTRICTION"];
  const severities = ["INFO", "WARN", "URGENT"];
  for (let d = 0; d < DAYS; d++) {
    const day = new Date(Date.now() - d * 864e5);
    for (let i = 0; i < ALERTS_PER_DAY; i++) {
      const createdAt = new Date(day.getTime() - Math.floor(Math.random() * 3600) * 1000).toISOString();
      events.push({
        org_id: demoOrgId,
        user_id: demoUserId,
        event_type: types[Math.floor(Math.random() * types.length)],
        severity: severities[Math.floor(Math.random() * severities.length)],
        title: `Demo alert D${d} #${i}`,
        message: `Simulated event for demo purposes`,
        source: "demo",
        geom: `POINT(${-120 + Math.random() * 40} ${30 + Math.random() * 15})`,
        created_at: createdAt,
      });
    }
  }
  if (events.length) await supabase.from("alert_events").upsert(events);

  // Safety daily summary (last 90 days)
  for (let d = 0; d < DAYS; d++) {
    const date = new Date(Date.now() - d * 864e5).toISOString().slice(0, 10);
    await supabase.from("safety_daily_summary").upsert({
      org_id: demoOrgId,
      summary_date: date,
      total_alerts: ALERTS_PER_DAY,
      urgent_alerts: Math.floor(ALERTS_PER_DAY * 0.15),
      unique_drivers: Math.floor(Math.random() * 10) + 3,
      top_types: [
        { type: "CONSTRUCTION", count: Math.floor(ALERTS_PER_DAY * 0.4) },
        { type: "WEATHER", count: Math.floor(ALERTS_PER_DAY * 0.2) },
      ],
    });
  }

  // Risk corridors
  const corridors = [
    { lat: 34.05, lon: -118.25, urgent: 12, total: 45 },
    { lat: 40.71, lon: -74.01, urgent: 8, total: 32 },
    { lat: 41.88, lon: -87.63, urgent: 6, total: 28 },
  ];
  for (const c of corridors) {
    await supabase.from("risk_corridor_cells").upsert({
      org_id: demoOrgId,
      cell: `POLYGON((${c.lon - 0.1} ${c.lat - 0.1},${c.lon + 0.1} ${c.lat - 0.1},${c.lon + 0.1} ${c.lat + 0.1},${c.lon - 0.1} ${c.lat + 0.1},${c.lon - 0.1} ${c.lat - 0.1}))`,
      alert_count: c.total,
      urgent_count: c.urgent,
      types: [{ type: "CONSTRUCTION", count: c.urgent }],
    });
  }

  console.log("✅ Demo data seeded for org:", demoOrgId, "days:", DAYS, "alerts:", events.length);
}

seed().catch((e) => {
  console.error(e);
  process.exit(1);
});
