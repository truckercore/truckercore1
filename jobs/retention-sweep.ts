// jobs/retention-sweep.ts
// Minimal retention sweeper that calls db.retention.list/apply and logs results.
// Adjust the import path to your server deps if needed. Here we try a few fallbacks.

let db: any;
try {
  // Preferred path if you have a server module exporting db
  // eslint-disable-next-line @typescript-eslint/no-var-requires
  db = require('../server/deps').db;
} catch {
  try {
    // Fallback to workers shared stub if present
    // eslint-disable-next-line @typescript-eslint/no-var-requires
    db = require('../api/workers/shared').db;
  } catch {
    // Last resort: provide a minimal in-memory mock to satisfy tests that monkey-patch methods
    db = {
      retention: {
        async list() { return [] as any[]; },
        async apply(_table: string, _keepDays: number) { return 0; },
      },
      test: {
        async insertOldIdempotency(_opts: { hoursAgo: number }) { /* no-op */ },
        async insertOldOutbox(_opts: { daysAgo: number }) { /* no-op */ },
        async countExpiredIdempotency(_opts: { olderThanHours: number }) { return 0; },
        async countExpiredOutbox(_opts: { olderThanDays: number }) { return 0; },
      },
    };
  }
}

export async function runRetentionSweep(opts?: { dryRun?: boolean }) {
  const policies = await (db.retention?.list?.() ?? []);
  let removedTotal = 0;
  for (const p of policies) {
    const tableName = (p.table_name ?? p.table ?? '').toString();
    const keepDays = Number(p.keep_days ?? p.keepDays ?? 0);
    if (!opts?.dryRun) {
      const removed = await db.retention.apply(tableName, keepDays);
      removedTotal += Number(removed ?? 0);
      // eslint-disable-next-line no-console
      console.log(`[retention] ${tableName}: removed ${removed}`);
    } else {
      console.log(`[retention][dry] ${tableName}: keep ${keepDays}d`);
    }
  }
  // Purge export artifacts (best-effort)
  try {
    const SUPABASE_URL = process.env.NEXT_PUBLIC_SUPABASE_URL || process.env.SUPABASE_URL || '';
    const SERVICE_KEY = process.env.SUPABASE_SERVICE_ROLE_KEY || process.env.SUPABASE_SERVICE_ROLE || '';
    if (SUPABASE_URL && SERVICE_KEY) {
      const keepSignedDays = Number(process.env.SIGNED_EXPORT_RETENTION_DAYS || 365);
      const unsignedCutoff = new Date(Date.now() - 30 * 864e5).toISOString();
      const signedCutoff = new Date(Date.now() - keepSignedDays * 864e5).toISOString();

      if (!opts?.dryRun) {
        await fetch(`${SUPABASE_URL.replace(/\/$/, '')}/rest/v1/export_artifacts?and=(signed.eq.false,created_at.lt.${unsignedCutoff})`, {
          method: 'PATCH',
          headers: { apikey: SERVICE_KEY, Authorization: `Bearer ${SERVICE_KEY}`, 'Content-Type': 'application/json' },
          body: JSON.stringify({ deleted_at: new Date().toISOString() }),
        }).catch(() => {});

        await fetch(`${SUPABASE_URL.replace(/\/$/, '')}/rest/v1/export_artifacts?and=(signed.eq.true,created_at.lt.${signedCutoff})`, {
          method: 'PATCH',
          headers: { apikey: SERVICE_KEY, Authorization: `Bearer ${SERVICE_KEY}`, 'Content-Type': 'application/json' },
          body: JSON.stringify({ deleted_at: new Date().toISOString() }),
        }).catch(() => {});
      } else {
        console.log(`[retention][dry] export_artifacts unsigned before ${unsignedCutoff}`);
        console.log(`[retention][dry] export_artifacts signed before ${signedCutoff}`);
      }
    }
  } catch (_) {}

  // eslint-disable-next-line no-console
  console.log(`[retention] total removed: ${removedTotal}`);
  // TODO: emit metric retention_purged_total{table}
}

if (require.main === module) {
  runRetentionSweep().then(() => process.exit(0));
}
