// Minimal shared scaffolding to let workers/middleware compile or be type-checked locally.
// In real services, replace these with actual implementations.

export const db = {
  savedSearches: {
    async findActive() { return [] as any[]; },
  },
  loads: {
    async findSince(_since: Date) { return [] as any[]; },
  },
  loadAlerts: {
    async exists(_userId: string, _loadId: string) { return false; },
    async insert(_row: any) { /* no-op */ },
  },
  outbox: {
    async claimPending(_now: Date, _limit: number) { return [] as any[]; },
    async recordAttempt(_outboxId: string, _subscriptionId: string, _statusCode: number | null, _error: string | null, _nextDelaySeconds: number, _dead: boolean) { /* no-op */ },
    async markDelivered(_id: string) { /* no-op */ },
    async replayDead(_id: string) { /* no-op */ },
  },
  webhooks: {
    async activeFor(_orgId: string, _topic: string) { return [] as any[]; },
  },
  idempotency: {
    async find(_key: string) { return null as any; },
    async put(_row: any) { /* no-op */ },
  },
};

export const http = {
  async post(_url: string, _body: any, _opts: { headers?: Record<string,string>; timeout?: number }) {
    // Simulate success in scaffold
    return { status: 200 } as any;
  }
};

export async function publishEvent(topic: string, payload: any) {
  // In production, insert into event_outbox or enqueue via your event bus
  console.log('[publishEvent]', topic, payload);
}
