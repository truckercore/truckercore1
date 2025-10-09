import { EventEmitter } from 'events';

export interface QueueItem {
  id: string;
  operation: string;
  payload: any;
  attempts: number;
  maxAttempts: number;
  nextRetryAt: number;
  createdAt: number;
  lastError?: string;
  priority: 'high' | 'normal' | 'low';
}

export interface DLQItem extends QueueItem {
  failedAt: number;
  reason: string;
}

export class RetryQueue extends EventEmitter {
  private queue: QueueItem[] = [];
  private dlq: DLQItem[] = [];
  private timer: NodeJS.Timeout | null = null;
  private processing = false;

  start(intervalMs: number = 1000) {
    if (this.timer) return;
    this.timer = setInterval(() => {
      void this.processQueue();
    }, intervalMs);
  }

  stop() {
    if (this.timer) {
      clearInterval(this.timer);
      this.timer = null;
    }
  }

  async enqueue(operation: string, payload: any, opts: { maxAttempts?: number; priority?: 'high' | 'normal' | 'low'; delayMs?: number } = {}): Promise<string> {
    const id = `${operation}-${Date.now()}-${Math.random().toString(36).slice(2)}`;
    const item: QueueItem = {
      id,
      operation,
      payload,
      attempts: 0,
      maxAttempts: opts.maxAttempts ?? 5,
      nextRetryAt: Date.now() + (opts.delayMs ?? 0),
      createdAt: Date.now(),
      priority: opts.priority ?? 'normal'
    };
    this.queue.push(item);
    return id;
  }

  private async processQueue() {
    if (this.processing) return;
    this.processing = true;
    try {
      const now = Date.now();
      // sort by priority and nextRetryAt
      this.queue.sort((a, b) => {
        const prio = (p: QueueItem['priority']) => (p === 'high' ? 0 : p === 'normal' ? 1 : 2);
        const pa = prio(a.priority) - prio(b.priority);
        if (pa !== 0) return pa;
        return a.nextRetryAt - b.nextRetryAt;
      });
      for (const item of [...this.queue]) {
        if (item.nextRetryAt > now) continue;
        // Notify listener to process
        const result: boolean = await new Promise<boolean>((resolve) => {
          this.emit('process', {
            id: item.id,
            operation: item.operation,
            payload: item.payload,
            attempts: item.attempts,
            onSuccess: () => resolve(true),
            onFailure: () => resolve(false)
          });
        });
        if (result) {
          // remove from queue
          this.queue = this.queue.filter((q) => q.id !== item.id);
        } else {
          item.attempts++;
          if (item.attempts >= item.maxAttempts) {
            this.moveToDLQ(item, 'Max attempts exceeded');
          } else {
            // exponential backoff with jitter
            const backoff = this.calculateBackoff(item.attempts);
            item.nextRetryAt = Date.now() + backoff;
          }
        }
      }
    } finally {
      this.processing = false;
    }
  }

  private moveToDLQ(item: QueueItem, reason: string) {
    // remove
    this.queue = this.queue.filter((q) => q.id !== item.id);
    this.dlq.unshift({ ...item, failedAt: Date.now(), reason });
  }

  getDLQItems(limit: number = 50): DLQItem[] {
    return this.dlq.slice(0, limit);
  }

  clearDLQ(): number {
    const n = this.dlq.length;
    this.dlq = [];
    return n;
  }

  private calculateBackoff(attempt: number): number {
    const base = 1000; // 1s
    const max = 5 * 60 * 1000; // 5 min
    const exp = Math.min(base * Math.pow(2, attempt), max);
    const jitter = Math.random() * exp * 0.3;
    return Math.floor(exp + jitter);
  }

  close() {
    this.stop();
  }
}
