export async function runExportSweep() {
  const SUPABASE_URL = process.env.NEXT_PUBLIC_SUPABASE_URL || process.env.SUPABASE_URL;
  const SERVICE_KEY = process.env.SUPABASE_SERVICE_ROLE_KEY || process.env.SUPABASE_SERVICE_ROLE;
  if (!SUPABASE_URL || !SERVICE_KEY) return;

  // Purge DLQ older than 7d
  const dlqCutoff = new Date(Date.now() - 7 * 864e5).toISOString();
  await fetch(`${SUPABASE_URL.replace(/\/$/, "")}/rest/v1/export_dlq?created_at=lt.${dlqCutoff}`, {
    method: "DELETE",
    headers: { apikey: SERVICE_KEY, Authorization: `Bearer ${SERVICE_KEY}` },
  }).catch(() => {});

  // Purge temp artifacts deleted_at > 30d
  const artifactCutoff = new Date(Date.now() - 30 * 864e5).toISOString();
  await fetch(`${SUPABASE_URL.replace(/\/$/, "")}/rest/v1/export_artifacts?deleted_at=lt.${artifactCutoff}`, {
    method: "DELETE",
    headers: { apikey: SERVICE_KEY, Authorization: `Bearer ${SERVICE_KEY}` },
  }).catch(() => {});

  console.log("[export-sweep] OK");
}

// Allow running directly: node jobs/export-sweep.mjs
if (import.meta.url === `file://${process.argv[1]}`) {
  runExportSweep().catch((e) => {
    console.error(e);
    process.exit(1);
  });
}
