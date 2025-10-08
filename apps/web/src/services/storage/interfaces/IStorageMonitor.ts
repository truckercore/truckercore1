export interface OperationLatency {
  count: number;
  total: number; // total duration ms
  average: number;
  min: number;
  max: number;
  p50?: number;
  p95?: number;
  p99?: number;
}

export interface OperationStats {
  operation: string;
  count: number;
  errors: number;
  successRate: number; // percent 0..100
  latency: OperationLatency;
}

export interface StorageMetrics {
  totalOperations: number;
  successfulOperations: number;
  failedOperations: number;
  errorRate: number; // 0..1
  averageLatency: number; // ms
  operationCounts: Record<string, number>;
  operationLatencies: Record<string, OperationLatency>;
}

export interface StorageMonitor {
  recordOperation(
    operation: string,
    durationMs: number,
    success: boolean,
    metadata?: Record<string, any>
  ): void;

  getMetrics(): StorageMetrics;
  getOperationStats(operation: string): OperationStats;
  reset(): void;
}
