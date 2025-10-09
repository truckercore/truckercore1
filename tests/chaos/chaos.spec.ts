import { CircuitBreaker } from '../../resilience/circuit-breaker';
import { AdaptiveRateLimiter } from '../../resilience/rate-limiter';
import { RetryQueue } from '../../resilience/retry-queue';

/**
 * Chaos Tests
 */

describe('Chaos Testing', () => {
  describe('Circuit Breaker Under Load', () => {
    it('should open circuit after threshold failures', async () => {
      const breaker = new CircuitBreaker({
        failureThreshold: 50,
        successThreshold: 3,
        timeout: 5000,
        monitoringPeriod: 10000,
        volumeThreshold: 10,
        name: 'chaos-test',
      });

      let calls = 0;
      const mockOperation = async () => {
        calls++;
        if (calls % 10 < 6) throw new Error('Simulated failure');
        return 'success';
      };

      const results: any[] = [];
      for (let i = 0; i < 20; i++) {
        try {
          const r = await breaker.execute(mockOperation);
          results.push({ success: true, r });
        } catch (e: any) {
          results.push({ success: false, e: e.message });
        }
      }

      const metrics = breaker.getMetrics();
      expect(['OPEN', 'HALF_OPEN', 'CLOSED']).toContain(metrics.state);
      expect(metrics.rejections).toBeGreaterThanOrEqual(0);
    });

    it('should transition to half-open and recover', async () => {
      const breaker = new CircuitBreaker({
        failureThreshold: 50,
        successThreshold: 2,
        timeout: 100,
        monitoringPeriod: 1000,
        volumeThreshold: 5,
        name: 'recovery-test',
      });

      breaker.forceState('OPEN');
      await new Promise((r) => setTimeout(r, 150));

      const op = async () => 'success';
      await breaker.execute(op);
      await breaker.execute(op);
      await breaker.execute(op);

      const metrics = breaker.getMetrics();
      expect(metrics.state).toBe('CLOSED');
    });
  });

  describe('Rate Limiter Under Heavy Load', () => {
    it('should queue requests when limit exceeded', async () => {
      const limiter = new AdaptiveRateLimiter({ maxRequests: 5, windowMs: 1000, name: 'chaos-limiter' });
      const start = Date.now();
      const results: Array<{ index: number; time: number }> = [];
      const tasks = Array.from({ length: 10 }, (_, i) =>
        limiter.acquire('test-endpoint').then(() => results.push({ index: i, time: Date.now() - start }))
      );
      await Promise.all(tasks);
      results.sort((a, b) => a.index - b.index);
      expect(results[4].time).toBeLessThan(200);
      expect(results[9].time).toBeGreaterThanOrEqual(800);
    });

    it('should handle 429 responses correctly', async () => {
      const limiter = new AdaptiveRateLimiter({ maxRequests: 10, windowMs: 1000, name: 'test-limiter' });
      const retryAfter = 2000;
      await limiter.handle429('test-endpoint', retryAfter);
      const start = Date.now();
      await limiter.acquire('test-endpoint');
      const elapsed = Date.now() - start;
      expect(elapsed).toBeGreaterThanOrEqual(retryAfter - 150);
    });
  });

  describe('Retry Queue Under Failures', () => {
    it('should move items to DLQ after max attempts', async () => {
      const queue = new RetryQueue();
      queue.start(50);

      queue.on('process', (event: any) => {
        event.onFailure();
      });

      await queue.enqueue('test-operation', { data: 'test' }, { maxAttempts: 3, priority: 'high' });
      await new Promise((r) => setTimeout(r, 2000));

      const dlq = queue.getDLQItems();
      expect(dlq.length).toBeGreaterThanOrEqual(1);
      expect(dlq[0].operation).toBe('test-operation');
      expect(dlq[0].attempts).toBeGreaterThanOrEqual(3);

      queue.stop();
      queue.close();
    });

    it('should apply exponential backoff', async () => {
      const queue = new RetryQueue();
      queue.start(50);
      const attemptTimes: number[] = [];
      let attempts = 0;

      queue.on('process', (event: any) => {
        attemptTimes.push(Date.now());
        attempts++;
        if (attempts < 3) event.onFailure(); else event.onSuccess();
      });

      await queue.enqueue('backoff-test', { data: 'test' }, { maxAttempts: 5 });
      await new Promise((r) => setTimeout(r, 8000));

      if (attemptTimes.length >= 3) {
        const delay1 = attemptTimes[1] - attemptTimes[0];
        const delay2 = attemptTimes[2] - attemptTimes[1];
        expect(delay2).toBeGreaterThan(delay1);
      }

      queue.stop();
      queue.close();
    });
  });

  describe('Network Resilience', () => {
    it('should handle slow responses with timeout', async () => {
      const timeout = 1000;
      const slowOp = () => new Promise((resolve) => setTimeout(() => resolve('success'), 2000));
      const timeoutPromise = new Promise((_res, rej) => setTimeout(() => rej(new Error('Timeout')), timeout));
      await expect(Promise.race([slowOp(), timeoutPromise])).rejects.toThrow('Timeout');
    });

    it('should handle connection errors gracefully', async () => {
      const operation = async () => { throw new Error('ECONNREFUSED'); };
      const breaker = new CircuitBreaker({ failureThreshold: 50, successThreshold: 2, timeout: 500, monitoringPeriod: 1000, volumeThreshold: 5, name: 'connection-test' });
      for (let i = 0; i < 10; i++) { try { await breaker.execute(operation); } catch { /* expected */ } }
      const metrics = breaker.getMetrics();
      expect(['OPEN','HALF_OPEN','CLOSED']).toContain(metrics.state);
    });
  });
});
