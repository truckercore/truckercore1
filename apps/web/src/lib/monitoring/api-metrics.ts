import { NextRequest, NextResponse } from 'next/server';

interface RequestMetrics {
  method: string;
  path: string;
  statusCode: number;
  duration: number;
  timestamp: Date;
  userId?: string;
  error?: string;
}

class APIMonitoring {
  private metrics: RequestMetrics[] = [];
  private readonly maxMetrics = 10000;

  recordRequest(metrics: RequestMetrics) {
    this.metrics.push(metrics);
    if (this.metrics.length > this.maxMetrics) {
      this.metrics = this.metrics.slice(-this.maxMetrics);
    }
    if (metrics.duration > 5000) {
      console.warn('Slow API request:', {
        path: metrics.path,
        duration: `${metrics.duration}ms`,
        statusCode: metrics.statusCode,
      });
    }
    if (metrics.statusCode >= 400) {
      console.error('API error:', {
        path: metrics.path,
        statusCode: metrics.statusCode,
        error: metrics.error,
      });
    }
  }

  getSummary(timeWindow: number = 3600000) {
    const since = new Date(Date.now() - timeWindow);
    const recentMetrics = this.metrics.filter(m => m.timestamp >= since);

    const totalRequests = recentMetrics.length;
    const errors = recentMetrics.filter(m => m.statusCode >= 400);
    const slowRequests = recentMetrics.filter(m => m.duration > 1000);

    const avgDuration =
      recentMetrics.reduce((sum, m) => sum + m.duration, 0) / totalRequests || 0;

    const p95Duration = this.calculatePercentile(
      recentMetrics.map(m => m.duration),
      0.95
    );

    const p99Duration = this.calculatePercentile(
      recentMetrics.map(m => m.duration),
      0.99
    );

    const endpointStats = new Map<string, {
      count: number;
      avgDuration: number;
      errors: number;
    }>();

    recentMetrics.forEach(m => {
      const key = `${m.method} ${m.path}`;
      const existing = endpointStats.get(key) || {
        count: 0,
        avgDuration: 0,
        errors: 0,
      };

      existing.count++;
      existing.avgDuration = 
        (existing.avgDuration * (existing.count - 1) + m.duration) / existing.count;
      if (m.statusCode >= 400) existing.errors++;

      endpointStats.set(key, existing);
    });

    return {
      timeWindow: timeWindow / 1000,
      totalRequests,
      errorCount: errors.length,
      errorRate: totalRequests ? (errors.length / totalRequests) * 100 : 0,
      slowRequestCount: slowRequests.length,
      avgDuration,
      p95Duration,
      p99Duration,
      endpoints: Array.from(endpointStats.entries()).map(([endpoint, stats]) => ({
        endpoint,
        ...stats,
      })),
    };
  }

  private calculatePercentile(values: number[], percentile: number): number {
    if (values.length === 0) return 0;
    const sorted = [...values].sort((a, b) => a - b);
    const index = Math.ceil(sorted.length * percentile) - 1;
    return sorted[index];
  }

  clear() {
    this.metrics = [];
  }
}

export const apiMonitoring = new APIMonitoring();

export function withMetrics(
  handler: (req: NextRequest) => Promise<NextResponse>
) {
  return async (req: NextRequest): Promise<NextResponse> => {
    const startTime = Date.now();
    const path = new URL(req.url).pathname;
    const method = req.method;

    let response: NextResponse;
    let error: string | undefined;

    try {
      response = await handler(req);
    } catch (err: any) {
      error = err.message;
      throw err;
    } finally {
      const duration = Date.now() - startTime;
      apiMonitoring.recordRequest({
        method,
        path,
        statusCode: (response!?.status as number) || 500,
        duration,
        timestamp: new Date(),
        error,
      });
    }

    return response!;
  };
}
