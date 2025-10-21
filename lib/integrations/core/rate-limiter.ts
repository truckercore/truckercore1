interface RateLimitConfig {
  maxRequests: number;
  windowMs: number;
  minRequestInterval?: number; // ms between requests (jitter base)
}

interface VendorRateLimitHeaders {
  remaining?: number;
  reset?: number; // epoch seconds
  limit?: number;
}

export class AdaptiveRateLimiter {
  private tokens: number;
  private lastRefill: number;
  private readonly requestTimestamps: number[] = [];

  constructor(private readonly vendorName: string, private config: RateLimitConfig) {
    this.tokens = config.maxRequests;
    this.lastRefill = Date.now();
  }

  async acquire(): Promise<void> {
    await this.refillTokens();

    if (this.tokens < 1) {
      const waitTime = this.calculateWaitTime();
      await this.sleep(waitTime);
      await this.refillTokens();
    }

    this.tokens--;
    this.requestTimestamps.push(Date.now());

    // jittered delay between requests to avoid bursts
    const jitter = Math.random() * (this.config.minRequestInterval || 100);
    await this.sleep(jitter);
  }

  updateFromHeaders(headers: VendorRateLimitHeaders): void {
    if (headers.remaining !== undefined && headers.limit !== undefined) {
      const util = headers.limit === 0 ? 1 : headers.remaining / headers.limit;
      if (util < 0.2) {
        this.config.maxRequests = Math.max(Math.floor(this.config.maxRequests * 0.7), 1);
      } else if (util > 0.8 && this.config.maxRequests < (headers.limit || this.config.maxRequests)) {
        this.config.maxRequests = Math.min(Math.floor(this.config.maxRequests * 1.2), headers.limit || this.config.maxRequests);
      }
    }
    if (headers.reset) {
      const resetMs = headers.reset * 1000 - Date.now();
      if (resetMs > 0) this.config.windowMs = resetMs;
    }
  }

  private async refillTokens(): Promise<void> {
    const now = Date.now();
    const elapsed = now - this.lastRefill;
    if (elapsed >= this.config.windowMs) {
      this.tokens = this.config.maxRequests;
      this.lastRefill = now;
      const cutoff = now - this.config.windowMs;
      while (this.requestTimestamps.length > 0 && this.requestTimestamps[0] < cutoff) {
        this.requestTimestamps.shift();
      }
    }
  }

  private calculateWaitTime(): number {
    const now = Date.now();
    const windowStart = now - this.config.windowMs;
    const recent = this.requestTimestamps.filter((t) => t > windowStart);
    if (recent.length === 0) return 0;
    const oldest = recent[0];
    const wait = this.config.windowMs - (now - oldest);
    const jitter = Math.random() * 1000;
    return Math.max(wait + jitter, 0);
  }

  private sleep(ms: number) {
    return new Promise<void>((resolve) => setTimeout(resolve, ms));
  }

  getMetrics() {
    return {
      vendorName: this.vendorName,
      availableTokens: this.tokens,
      maxRequests: this.config.maxRequests,
      windowMs: this.config.windowMs,
      recentRequestCount: this.requestTimestamps.length,
    } as const;
  }
}
