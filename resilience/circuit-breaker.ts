export type CircuitState = 'CLOSED' | 'OPEN' | 'HALF_OPEN';

interface CircuitBreakerOptions {
  failureThreshold: number; // percentage (0-100)
  successThreshold: number; // number of consecutive successes to close from HALF_OPEN
  timeout: number; // ms before allowing half-open probe
  monitoringPeriod: number; // ms window for calculating failure rate
  volumeThreshold: number; // minimum number of requests in window before evaluating
  name?: string;
}

interface Metrics {
  state: CircuitState;
  rejections: number;
  failures: number;
  successes: number;
  name?: string;
}

export class CircuitBreaker {
  private opts: CircuitBreakerOptions;
  private state: CircuitState = 'CLOSED';
  private lastOpenedAt = 0;
  private rejections = 0;
  private successes = 0;
  private failures = 0;
  private recent: Array<{ t: number; ok: boolean }>; // rolling window

  constructor(opts: CircuitBreakerOptions) {
    this.opts = opts;
    this.recent = [];
  }

  async execute<T>(fn: () => Promise<T>): Promise<T> {
    const now = Date.now();
    // Prune recent window
    const cutoff = now - this.opts.monitoringPeriod;
    this.recent = this.recent.filter((r) => r.t >= cutoff);

    if (this.state === 'OPEN') {
      // Allow half-open probe after timeout
      if (now - this.lastOpenedAt < this.opts.timeout) {
        this.rejections++;
        throw new Error('Circuit open');
      }
      this.state = 'HALF_OPEN';
    }

    try {
      const res = await fn();
      this.record(true);
      if (this.state === 'HALF_OPEN') {
        // count successes in HALF_OPEN
        if (this.consecutiveSuccesses() >= this.opts.successThreshold) {
          this.state = 'CLOSED';
        }
      } else if (this.state === 'CLOSED') {
        this.maybeOpen();
      }
      return res;
    } catch (e) {
      this.record(false);
      if (this.state === 'HALF_OPEN') {
        // immediately open again on failure in HALF_OPEN
        this.open();
      } else if (this.state === 'CLOSED') {
        this.maybeOpen();
      }
      throw e;
    }
  }

  private record(ok: boolean) {
    const now = Date.now();
    this.recent.push({ t: now, ok });
    if (ok) this.successes++; else this.failures++;
  }

  private consecutiveSuccesses(): number {
    let c = 0;
    for (let i = this.recent.length - 1; i >= 0; i--) {
      if (this.recent[i].ok) c++; else break;
    }
    return c;
  }

  private failureRate(): number {
    if (this.recent.length === 0) return 0;
    const failures = this.recent.filter((r) => !r.ok).length;
    return (failures / this.recent.length) * 100;
  }

  private maybeOpen() {
    if (this.recent.length < this.opts.volumeThreshold) return;
    if (this.failureRate() >= this.opts.failureThreshold) {
      this.open();
    }
  }

  private open() {
    this.state = 'OPEN';
    this.lastOpenedAt = Date.now();
  }

  forceState(state: CircuitState) {
    this.state = state;
    if (state === 'OPEN') this.lastOpenedAt = Date.now();
  }

  getMetrics(): Metrics {
    return { state: this.state, rejections: this.rejections, failures: this.failures, successes: this.successes, name: this.opts.name };
  }
}
