#!/usr/bin/env node
import fs from 'fs';
import path from 'path';
import process from 'process';
import IORedis from 'ioredis';

/**
 * Export Dead Letter Queue (DLQ) items from Redis to a timestamped JSON file.
 * Usage:
 *   node scripts/dlq/export-dlq.mjs [--key integration_retry_queue:dlq] [--out-dir ./]
 * Env:
 *   REDIS_URL (e.g., redis://localhost:6379)
 */

const args = new Map();
for (let i = 2; i < process.argv.length; i++) {
  const a = process.argv[i];
  if (a.startsWith('--')) {
    const [k, v] = a.replace(/^--/, '').split('=');
    args.set(k, v ?? 'true');
  }
}

const DLQ_KEY = args.get('key') || 'integration_retry_queue:dlq';
const OUT_DIR = args.get('out-dir') || '.';
const redisUrl = process.env.REDIS_URL || 'redis://localhost:6379';

(async () => {
  const redis = new IORedis(redisUrl);
  try {
    const items = await redis.lrange(DLQ_KEY, 0, -1);
    const ts = new Date();
    const stamp = ts.toISOString().replace(/[-:]/g, '').replace(/\..+/, '');
    const filename = path.join(OUT_DIR, `dlq_backup_${stamp}.json`);

    // Normalize into an array of parsed JSON objects where possible
    const parsed = items.map((raw) => {
      try { return JSON.parse(raw); } catch { return { raw }; }
    });

    fs.writeFileSync(filename, JSON.stringify(parsed, null, 2), 'utf8');

    // Print quick summary
    const countByOp = parsed.reduce((acc, it) => {
      const op = it.operation || it.payload?.operation || 'unknown';
      acc[op] = (acc[op] || 0) + 1;
      return acc;
    }, {});

    // eslint-disable-next-line no-console
    console.log(`✓ Exported ${parsed.length} DLQ items to ${filename}`);
    // eslint-disable-next-line no-console
    console.log('By operation:', countByOp);
  } catch (err) {
    console.error('✗ Failed to export DLQ:', err?.message || err);
    process.exitCode = 1;
  } finally {
    redis.disconnect();
  }
})();
