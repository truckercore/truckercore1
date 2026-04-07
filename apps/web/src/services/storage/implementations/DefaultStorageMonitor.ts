import { StorageMetrics, OperationLatency, OperationStats, StorageMonitor } from '../interfaces/IStorageMonitor';

// Simple in-memory implementation with naive percentile calculation
class DefaultStorageMonitorImpl implements StorageMonitor {
  private static _instance: DefaultStorageMonitorImpl | null = null;
  static getInstance(): DefaultStorageMonitorImpl {
    if (!DefaultStorageMonitorImpl._instance) {
      DefaultStorageMonitorImpl._instance = new DefaultStorageMonitorImpl();
    }
    return DefaultStorageMonitorImpl._instance;
  }

  private durationsByOp: Map<string, number[]> = new Map();
  private countsByOp: Map<string, { ok: number; err: number }> = new Map();

  recordOperation(operation: string, durationMs: number, success: boolean, _metadata: Record<string, any> = {}): void {
    const arr = this.durationsByOp.get(operation) ?? [];
    arr.push(durationMs);
    this.durationsByOp.set(operation, arr);
    const c = this.countsByOp.get(operation) ?? { ok: 0, err: 0 };
    if (success) c.ok++; else c.err++;
    this.countsByOp.set(operation, c);
  }

  getMetrics(): StorageMetrics {
    let total = 0;
    let ok = 0;
    let err = 0;
    let totalLatency = 0;

    const operationCounts: Record<string, number> = {};
    const operationLatencies: Record<string, OperationLatency> = {};

    for (const [op, arr] of this.durationsByOp.entries()) {
      const counts = this.countsByOp.get(op) ?? { ok: 0, err: 0 };
      const stats = this.calcLatency(arr);
      operationCounts[op] = counts.ok + counts.err;
      operationLatencies[op] = stats;

      total += counts.ok + counts.err;
      ok += counts.ok;
      err += counts.err;
      totalLatency += stats.total;
    }

    const averageLatency = total > 0 ? totalLatency / total : 0;

    return {
      totalOperations: total,
      successfulOperations: ok,
      failedOperations: err,
      errorRate: total === 0 ? 0 : err / total,
      averageLatency,
      operationCounts,
      operationLatencies,
    };
  }

  getOperationStats(operation: string): OperationStats {
    const arr = this.durationsByOp.get(operation) ?? [];
    const counts = this.countsByOp.get(operation) ?? { ok: 0, err: 0 };
    const latency = this.calcLatency(arr);
    const count = counts.ok + counts.err;
    const successRate = count === 0 ? 0 : (counts.ok / count) * 100;
    return {
      operation,
      count,
      errors: counts.err,
      successRate,
      latency,
    };
  }

  reset(): void {
    this.durationsByOp.clear();
    this.countsByOp.clear();
  }

  // Helpers
  private calcLatency(arr: number[]): OperationLatency {
    if (arr.length === 0) {
      return { count: 0, total: 0, average: 0, min: 0, max: 0 };
    }
    const sorted = [...arr].sort((a, b) => a - b);
    const total = sorted.reduce((s, v) => s + v, 0);
    const average = total / sorted.length;
    const min = sorted[0];
    const max = sorted[sorted.length - 1];
    const p = (q: number) => this.percentile(sorted, q);
    return {
      count: sorted.length,
      total,
      average,
      min,
      max,
      p50: p(50),
      p95: p(95),
      p99: p(99),
    };
  }

  private percentile(sorted: number[], q: number): number {
    if (sorted.length === 0) return 0;
    const idx = (q / 100) * (sorted.length - 1);
    const lo = Math.floor(idx);
    const hi = Math.ceil(idx);
    if (lo === hi) return sorted[lo];
    const w = idx - lo;
    return sorted[lo] * (1 - w) + sorted[hi] * w;
  }
}

export const DefaultStorageMonitor = DefaultStorageMonitorImpl;
export type { StorageMetrics, OperationLatency, OperationStats };
