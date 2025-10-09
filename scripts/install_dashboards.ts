// scripts/install_dashboards.ts
import { createClient } from "@supabase/supabase-js";

async function main() {
  const url = process.env.SUPABASE_URL || process.env.NEXT_PUBLIC_SUPABASE_URL;
  const key = process.env.SUPABASE_SERVICE_ROLE_KEY || process.env.SUPABASE_SERVICE_ROLE || process.env.SUPABASE_SERVICE_KEY;
  const orgId = process.argv[2];
  if (!url || !key) throw new Error("Missing SUPABASE_URL or service role key");
  if (!orgId) throw new Error("Usage: ts-node scripts/install_dashboards.ts <org_id>");
  const sb = createClient(url.replace(/\/$/, ""), key, { auth: { persistSession: false } });

  const { error: rpcErr } = await sb.rpc("install_dashboards_for_org", { p_org: orgId });
  if (rpcErr) throw rpcErr;

  // Ensure defaults are enabled explicitly (idempotent upserts)
  const features = ["safety_summary", "export_alerts_csv", "risk_corridors"] as const;
  for (const f of features) {
    await fetch(`${url.replace(/\/$/, "")}/rest/v1/dashboards_org_features`, {
      method: "POST",
      headers: {
        apikey: key,
        Authorization: `Bearer ${key}`,
        "Content-Type": "application/json",
        Prefer: "resolution=merge-duplicates",
      },
      body: JSON.stringify({ org_id: orgId, feature_key: f, enabled: true }),
    });
  }
  console.log(`Dashboards installed for org ${orgId}`);
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});
