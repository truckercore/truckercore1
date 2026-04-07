interface RateLimiterOptions {
  maxRequests: number; // per window
  windowMs: number; // window size
  name?: string;
}

export class AdaptiveRateLimiter {
  private opts: RateLimiterOptions;
  private queues: Map<string, Array<() => void>> = new Map();
  private counters: Map<string, { count: number; windowStart: number; pauseUntil?: number }> = new Map();

  constructor(opts: RateLimiterOptions) {
    this.opts = opts;
  }

  async acquire(endpoint: string): Promise<void> {
    const now = Date.now();
    const ctr = this.counters.get(endpoint) || { count: 0, windowStart: now, pauseUntil: undefined };

    // Respect pause (after 429)
    if (ctr.pauseUntil && now < ctr.pauseUntil) {
      await new Promise<void>((resolve) => setTimeout(resolve, ctr.pauseUntil - now));
    }

    // Reset window if needed
    if (now - ctr.windowStart >= this.opts.windowMs) {
      ctr.windowStart = now;
      ctr.count = 0;
    }

    if (ctr.count < this.opts.maxRequests) {
      ctr.count++;
      this.counters.set(endpoint, ctr);
      return; // immediate
    }

    // Queue request until window refreshes
    return await new Promise<void>((resolve) => {
      const q = this.queues.get(endpoint) || [];
      q.push(resolve);
      this.queues.set(endpoint, q);
      const delay = ctr.windowStart + this.opts.windowMs - now;
      setTimeout(() => {
        // release next in queue (respecting new window)
        const next = this.queues.get(endpoint) || [];
        const res = next.shift();
        if (res) {
          // update counter for new window
          const nnow = Date.now();
          const c2 = this.counters.get(endpoint) || { count: 0, windowStart: nnow } as any;
          if (nnow - c2.windowStart >= this.opts.windowMs) {
            c2.windowStart = nnow;
            c2.count = 0;
          }
          c2.count++;
          this.counters.set(endpoint, c2);
          res();
        }
        this.queues.set(endpoint, next);
      }, Math.max(0, delay));
    });
  }

  async handle429(endpoint: string, retryAfterMs: number) {
    const ctr = this.counters.get(endpoint) || { count: 0, windowStart: Date.now(), pauseUntil: undefined };
    ctr.pauseUntil = Date.now() + retryAfterMs;
    this.counters.set(endpoint, ctr);
  }
}
