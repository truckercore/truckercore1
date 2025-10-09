// tests/retention.spec.ts
import { runRetentionSweep } from '../jobs/retention-sweep';

// Provide a mock db via jest module factory for the fallback import used by the job
const state = {
  idem: [] as { created_at: Date }[],
  outbox: [] as { created_at: Date }[],
};

jest.mock('../api/workers/shared', () => {
  const db = {
    test: {
      async insertOldIdempotency({ hoursAgo }: { hoursAgo: number }) {
        state.idem.push({ created_at: new Date(Date.now() - hoursAgo * 3600_000) });
      },
      async insertOldOutbox({ daysAgo }: { daysAgo: number }) {
        state.outbox.push({ created_at: new Date(Date.now() - daysAgo * 24 * 3600_000) });
      },
      async countExpiredIdempotency({ olderThanHours }: { olderThanHours: number }) {
        const cutoff = Date.now() - olderThanHours * 3600_000;
        return state.idem.filter((r) => r.created_at.getTime() < cutoff).length;
      },
      async countExpiredOutbox({ olderThanDays }: { olderThanDays: number }) {
        const cutoff = Date.now() - olderThanDays * 24 * 3600_000;
        return state.outbox.filter((r) => r.created_at.getTime() < cutoff).length;
      },
    },
    retention: {
      async list() {
        return [
          { table_name: 'idempotency_keys', keep_days: 3 },
          { table_name: 'outbox_events', keep_days: 7 },
        ];
      },
      async apply(table: string, keepDays: number) {
        const cutoff = Date.now() - keepDays * 24 * 3600_000;
        if (table === 'idempotency_keys') {
          const before = state.idem.length;
          state.idem = state.idem.filter((r) => r.created_at.getTime() >= cutoff);
          return before - state.idem.length;
        }
        if (table === 'outbox_events') {
          const before = state.outbox.length;
          state.outbox = state.outbox.filter((r) => r.created_at.getTime() >= cutoff);
          return before - state.outbox.length;
        }
        return 0;
      },
    },
  };
  return { db };
});

describe('Retention sweep', () => {
  it('removes rows older than keep_days per policy', async () => {
    const { db } = require('../api/workers/shared');
    await db.test.insertOldIdempotency({ hoursAgo: 100 }); // TTL ~ 72h
    await db.test.insertOldOutbox({ daysAgo: 10 }); // keep_days 7

    // Sanity: counts before
    const preIdem = await db.test.countExpiredIdempotency({ olderThanHours: 72 });
    const preOutbox = await db.test.countExpiredOutbox({ olderThanDays: 7 });
    expect(preIdem).toBeGreaterThanOrEqual(1);
    expect(preOutbox).toBeGreaterThanOrEqual(1);

    await runRetentionSweep();

    const idemCount = await db.test.countExpiredIdempotency({ olderThanHours: 72 });
    const outboxCount = await db.test.countExpiredOutbox({ olderThanDays: 7 });
    expect(idemCount).toBe(0);
    expect(outboxCount).toBe(0);
  });
});
