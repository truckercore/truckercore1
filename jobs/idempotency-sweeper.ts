// jobs/idempotency-sweeper.ts
// Nightly job: purge expired idempotency rows from api_idempotency_keys

const SUPABASE_URL = process.env.SUPABASE_URL || process.env.NEXT_PUBLIC_SUPABASE_URL;
const SERVICE_KEY = process.env.SUPABASE_SERVICE_ROLE_KEY || process.env.SUPABASE_SERVICE_ROLE || process.env.SUPABASE_SERVICE_KEY;

export async function runIdempotencySweeper(ttlHours = 72) {
  if (!SUPABASE_URL || !SERVICE_KEY) {
    console.error('[idempotency] Missing SUPABASE_URL or service role key');
    return;
  }
  const cutoff = new Date(Date.now() - ttlHours * 3600_000).toISOString();
  const url = new URL(`${SUPABASE_URL.replace(/\/$/, '')}/rest/v1/api_idempotency_keys`);
  url.searchParams.set('expires_at', `lt.${cutoff}`);
  try {
    const res = await fetch(url.toString(), {
      method: 'DELETE',
      headers: {
        apikey: SERVICE_KEY,
        Authorization: `Bearer ${SERVICE_KEY}`
      }
    });
    if (!res.ok) {
      const t = await res.text().catch(() => '');
      throw new Error(`delete failed: ${res.status} ${t}`);
    }
    const txt = await res.text().catch(() => '');
    const at = new Date().toISOString();
    console.log(`[idempotency] ${at} swept (TTL=${ttlHours}h) → ${txt || 'OK'}`);
  } catch (e: any) {
    console.error('[idempotency] sweeper failed:', e?.message || String(e));
  }
}

// CLI entrypoint
if (require.main === module) {
  const ttl = Number(process.env.IDEM_TTL_HOURS || 72);
  runIdempotencySweeper(ttl).then(() => process.exit(0));
}
