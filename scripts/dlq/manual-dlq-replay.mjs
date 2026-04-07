#!/usr/bin/env node
import fs from 'fs';
import IORedis from 'ioredis';

/**
 * Manually replay P1 items (dispatch, assignment) from a DLQ export file into the pending queue.
 * Usage:
 *   node scripts/dlq/manual-dlq-replay.mjs <p1_items.json> [--pending integration_retry_queue:pending] [--delay 5000]
 * Env:
 *   REDIS_URL
 */

const file = process.argv[2];
if (!file) {
  console.error('Usage: node scripts/dlq/manual-dlq-replay.mjs <p1_items.json>');
  process.exit(1);
}

const args = new Map();
for (let i = 3; i < process.argv.length; i++) {
  const a = process.argv[i];
  if (a.startsWith('--')) {
    const [k, v] = a.replace(/^--/, '').split('=');
    args.set(k, v ?? 'true');
  }
}

const PENDING_KEY = args.get('pending') || 'integration_retry_queue:pending';
const delayMs = parseInt(args.get('delay') || '5000', 10);
const redisUrl = process.env.REDIS_URL || 'redis://localhost:6379';

(async () => {
  const redis = new IORedis(redisUrl);
  try {
    const raw = fs.readFileSync(file, 'utf8');
    const items = JSON.parse(raw);
    if (!Array.isArray(items)) throw new Error('Input file must be a JSON array');

    const allowed = new Set(['dispatch', 'assignment']);
    let success = 0;
    let skipped = 0;

    for (const item of items) {
      const op = item?.operation || item?.payload?.operation;
      if (!allowed.has(op)) { skipped++; continue; }

      const job = {
        id: item.id || `${Date.now()}-${Math.random().toString(36).slice(2)}`,
        vendor: item.vendor || item.payload?.vendor || 'unknown',
        operation: op,
        payload: item.payload || item.payload === undefined ? item.payload : item,
        attempts: 0,
        maxAttempts: item.maxAttempts || 5,
        nextRetry: Date.now() + delayMs,
        createdAt: item.createdAt || Date.now(),
        lastError: undefined,
        priority: item.priority || 'high',
      };

      await redis.zadd(PENDING_KEY, job.nextRetry, JSON.stringify(job));
      success++;
    }

    console.log(`✓ Re-queued ${success} P1 items (skipped ${skipped})`);
  } catch (e) {
    console.error('✗ Manual replay failed:', e?.message || e);
    process.exitCode = 1;
  } finally {
    redis.disconnect();
  }
})();
