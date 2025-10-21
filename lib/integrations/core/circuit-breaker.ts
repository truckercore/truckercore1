import EventEmitter from 'events';

export interface CircuitBreakerConfig {
  failureThreshold: number; // number of consecutive failures to open
  successThreshold: number; // number of consecutive successes to close
  timeout: number;          // execution timeout for wrapped fn (ms)
  resetTimeout: number;     // time to wait before HALF_OPEN probe (ms)
}

export enum CircuitState {
  CLOSED = 'CLOSED',
  OPEN = 'OPEN',
  HALF_OPEN = 'HALF_OPEN',
}

/**
 * Simple circuit breaker with time-based HALF_OPEN
 */
export class CircuitBreaker extends EventEmitter {
  private state: CircuitState = CircuitState.CLOSED;
  private failureCount = 0;
  private successCount = 0;
  private nextAttempt = Date.now();

  constructor(private readonly name: string, private readonly config: CircuitBreakerConfig) {
    super();
  }

  async execute<T>(fn: () => Promise<T>): Promise<T> {
    if (this.state === CircuitState.OPEN) {
      if (Date.now() < this.nextAttempt) {
        const err = new Error(`Circuit breaker [${this.name}] is OPEN`);
        (err as any).circuitOpen = true;
        throw err;
      }
      this.state = CircuitState.HALF_OPEN;
      this.emit('halfOpen', { name: this.name });
    }

    const to = new Promise<never>((_, reject) =>
      setTimeout(() => reject(new Error(`Circuit breaker timeout: ${this.name}`)), this.config.timeout)
    );

    try {
      const result = await Promise.race([fn(), to]);
      this.onSuccess();
      return result as T;
    } catch (error) {
      this.onFailure();
      throw error;
    }
  }

  private onSuccess(): void {
    this.failureCount = 0;
    if (this.state === CircuitState.HALF_OPEN) {
      this.successCount++;
      if (this.successCount >= this.config.successThreshold) {
        this.state = CircuitState.CLOSED;
        this.successCount = 0;
        this.emit('closed', { name: this.name });
      }
    }
  }

  private onFailure(): void {
    this.failureCount++;
    this.successCount = 0;

    if (this.failureCount >= this.config.failureThreshold) {
      this.state = CircuitState.OPEN;
      this.nextAttempt = Date.now() + this.config.resetTimeout;
      this.emit('open', { name: this.name, nextAttempt: this.nextAttempt });
    }
  }

  getState(): CircuitState {
    return this.state;
  }

  getMetrics() {
    return {
      name: this.name,
      state: this.state,
      failureCount: this.failureCount,
      successCount: this.successCount,
      nextAttempt: this.nextAttempt,
    } as const;
  }
}
