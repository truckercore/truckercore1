import { EventEmitter } from 'events';
import IORedis from 'ioredis';

export interface RetryJob {
  id: string;
  vendor: string;
  operation: string;
  payload: any;
  attempts: number;
  maxAttempts: number;
  nextRetry: number;
  createdAt: number;
  idempotencyKey?: string;
}

/**
 * Redis-backed persistent retry queue with DLQ.
 * Uses a sorted set for pending jobs (score=nextRetry) and a list for DLQ.
 */
export class PersistentRetryQueue extends EventEmitter {
  private readonly redis: IORedis;
  private readonly queueKey: string;
  private readonly dlqKey: string;
  private processing = false;

  constructor(private readonly redisUrl: string, private readonly queueName: string = 'integration_retry_queue') {
    super();
    this.redis = new IORedis(redisUrl);
    this.queueKey = `${queueName}:pending`;
    this.dlqKey = `${queueName}:dlq`;
  }

  async enqueue(job: Omit<RetryJob, 'id' | 'attempts' | 'createdAt'>): Promise<string> {
    const fullJob: RetryJob = {
      ...job,
      id: this.generateId(),
      attempts: 0,
      createdAt: Date.now(),
    };
    await this.redis.zadd(this.queueKey, fullJob.nextRetry, JSON.stringify(fullJob));
    this.emit('enqueued', { jobId: fullJob.id, vendor: fullJob.vendor });
    return fullJob.id;
  }

  async startProcessing(handler: (job: RetryJob) => Promise<void>, pollIntervalMs: number = 5000): Promise<void> {
    this.processing = true;
    while (this.processing) {
      try {
        const now = Date.now();
        const jobs = await this.redis.zrangebyscore(this.queueKey, '-inf', now, 'LIMIT', 0, 10);
        for (const jobStr of jobs) {
          const job: RetryJob = JSON.parse(jobStr);
          try {
            await handler(job);
            await this.redis.zrem(this.queueKey, jobStr);
            this.emit('success', { jobId: job.id, vendor: job.vendor });
          } catch (error) {
            await this.handleFailure(job, jobStr, error);
          }
        }
      } catch (error) {
        this.emit('error', { error, context: 'processing_loop' });
      }
      await this.sleep(pollIntervalMs);
    }
  }

  private async handleFailure(job: RetryJob, jobStr: string, error: any): Promise<void> {
    job.attempts++;
    if (job.attempts >= job.maxAttempts) {
      await this.redis.lpush(this.dlqKey, JSON.stringify({ ...job, error: String(error) }));
      await this.redis.zrem(this.queueKey, jobStr);
      this.emit('dlq', { jobId: job.id, vendor: job.vendor, error });
    } else {
      const backoffMs = Math.min(1000 * Math.pow(2, job.attempts) + Math.random() * 1000, 60 * 60 * 1000);
      job.nextRetry = Date.now() + backoffMs;
      await this.redis.zrem(this.queueKey, jobStr);
      await this.redis.zadd(this.queueKey, job.nextRetry, JSON.stringify(job));
      this.emit('retry_scheduled', {
        jobId: job.id,
        vendor: job.vendor,
        attempt: job.attempts,
        nextRetry: job.nextRetry,
      });
    }
  }

  async getDLQSize(): Promise<number> {
    return await this.redis.llen(this.dlqKey);
  }

  async getQueueSize(): Promise<number> {
    return await this.redis.zcard(this.queueKey);
  }

  stopProcessing(): void {
    this.processing = false;
  }

  private generateId(): string {
    return `${Date.now()}-${Math.random().toString(36).substr(2, 9)}`;
  }

  private sleep(ms: number): Promise<void> {
    return new Promise((resolve) => setTimeout(resolve, ms));
  }
}
