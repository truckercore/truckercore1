#!/usr/bin/env node
import IORedis from 'ioredis';

/**
 * Automated DLQ replay: move all items from DLQ (list) back to pending (zset)
 * with configurable delay and batch size. Resets attempts to 0.
 * Usage:
 *   node scripts/dlq/replay-dlq.mjs [--dlq integration_retry_queue:dlq] [--pending integration_retry_queue:pending] [--delay 60000] [--batch-size 10] [--dry-run]
 * Env:
 *   REDIS_URL
 */

const args = new Map();
for (let i = 2; i < process.argv.length; i++) {
  const a = process.argv[i];
  if (a.startsWith('--')) {
    const [k, v] = a.replace(/^--/, '').split('=');
    args.set(k, v ?? 'true');
  }
}

const DLQ_KEY = args.get('dlq') || 'integration_retry_queue:dlq';
const PENDING_KEY = args.get('pending') || 'integration_retry_queue:pending';
const delayMs = parseInt(args.get('delay') || '60000', 10);
const batchSize = parseInt(args.get('batch-size') || '10', 10);
const dryRun = args.get('dry-run') === 'true';
const redisUrl = process.env.REDIS_URL || 'redis://localhost:6379';

(async () => {
  const redis = new IORedis(redisUrl);
  try {
    const items = await redis.lrange(DLQ_KEY, 0, -1);
    if (!items || items.length === 0) {
      console.log('DLQ is empty');
      redis.disconnect();
      return;
    }

    console.log(`Found ${items.length} items in DLQ`);

    let processed = 0;
    for (let i = 0; i < items.length; i += batchSize) {
      const batch = items.slice(i, i + batchSize);
      for (const raw of batch) {
        let job;
        try { job = JSON.parse(raw); } catch { job = { raw }; }
        job.attempts = 0;
        job.nextRetry = Date.now() + delayMs;
        job.createdAt = job.createdAt || Date.now();
        job.maxAttempts = job.maxAttempts || 5;
        job.priority = job.priority || 'normal';
        const score = job.nextRetry;
        if (!dryRun) {
          await redis.zadd(PENDING_KEY, score, JSON.stringify(job));
        }
        processed++;
      }
      console.log(`Replayed batch ${Math.floor(i / batchSize) + 1}`);
      if (!dryRun) await new Promise((r) => setTimeout(r, 500));
    }

    if (!dryRun) {
      await redis.del(DLQ_KEY);
      console.log('✓ DLQ cleared after replay');
    }
    console.log(`✓ Replay complete. Items processed: ${processed}`);
  } catch (e) {
    console.error('✗ DLQ replay failed:', e?.message || e);
    process.exitCode = 1;
  } finally {
    redis.disconnect();
  }
})();
