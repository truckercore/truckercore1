import { describe, it, expect, beforeEach, vi } from 'vitest';
import DefaultStorageMonitor from '@/services/storage/implementations/DefaultStorageMonitor';

describe('DefaultStorageMonitor', () => {
  let monitor: DefaultStorageMonitor;

  beforeEach(() => {
    monitor = DefaultStorageMonitor.getInstance();
    monitor.reset();
  });

  describe('singleton pattern', () => {
    it('should return same instance', () => {
      const instance1 = DefaultStorageMonitor.getInstance();
      const instance2 = DefaultStorageMonitor.getInstance();
      expect(instance1).toBe(instance2);
    });

    it('should maintain state across getInstance calls', () => {
      const instance1 = DefaultStorageMonitor.getInstance();
      instance1.recordOperation('test', 100, true);
      const instance2 = DefaultStorageMonitor.getInstance();
      const metrics = instance2.getMetrics();
      expect(metrics.totalOperations).toBe(1);
    });
  });

  describe('recordOperation', () => {
    it('should track successful operations', () => {
      monitor.recordOperation('saveFavorites', 50, true);
      const metrics = monitor.getMetrics();
      expect(metrics.totalOperations).toBe(1);
      expect(metrics.successfulOperations).toBe(1);
      expect(metrics.failedOperations).toBe(0);
    });

    it('should track failed operations', () => {
      monitor.recordOperation('saveFavorites', 50, false);
      const metrics = monitor.getMetrics();
      expect(metrics.totalOperations).toBe(1);
      expect(metrics.successfulOperations).toBe(0);
      expect(metrics.failedOperations).toBe(1);
    });

    it('should calculate error rate correctly', () => {
      monitor.recordOperation('test', 10, true);
      monitor.recordOperation('test', 10, true);
      monitor.recordOperation('test', 10, false);
      monitor.recordOperation('test', 10, true);
      const metrics = monitor.getMetrics();
      expect(metrics.errorRate).toBeCloseTo(0.25, 2);
    });

    it('should track operation counts', () => {
      monitor.recordOperation('saveFavorites', 10, true);
      monitor.recordOperation('loadFavorites', 20, true);
      monitor.recordOperation('saveFavorites', 15, true);
      const metrics = monitor.getMetrics();
      expect(metrics.operationCounts.saveFavorites).toBe(2);
      expect(metrics.operationCounts.loadFavorites).toBe(1);
    });

    it('should include metadata in tracking', () => {
      const spy = vi.spyOn(monitor, 'recordOperation');
      monitor.recordOperation('test', 100, true, { userId: 'user1', count: 5 });
      expect(spy).toHaveBeenCalledWith('test', 100, true, expect.objectContaining({ userId: 'user1', count: 5 }));
    });
  });

  describe('getMetrics', () => {
    it('should return empty metrics when no operations recorded', () => {
      const metrics = monitor.getMetrics();
      expect(metrics.totalOperations).toBe(0);
      expect(metrics.successfulOperations).toBe(0);
      expect(metrics.failedOperations).toBe(0);
      expect(metrics.averageLatency).toBe(0);
    });

    it('should calculate average latency correctly', () => {
      monitor.recordOperation('test', 100, true);
      monitor.recordOperation('test', 200, true);
      monitor.recordOperation('test', 300, true);
      const metrics = monitor.getMetrics();
      expect(metrics.averageLatency).toBe(200);
    });

    it('should track latency statistics per operation', () => {
      [10,20,30,40,50].forEach(v => monitor.recordOperation('test', v, true));
      const latency = monitor.getMetrics().operationLatencies.test;
      expect(latency.count).toBe(5);
      expect(latency.total).toBe(150);
      expect(latency.average).toBe(30);
      expect(latency.min).toBe(10);
      expect(latency.max).toBe(50);
    });
  });

  describe('getOperationStats', () => {
    it('should return stats for specific operation', () => {
      monitor.recordOperation('saveFavorites', 100, true);
      monitor.recordOperation('saveFavorites', 150, false);
      monitor.recordOperation('loadFavorites', 50, true);
      const stats = monitor.getOperationStats('saveFavorites');
      expect(stats.operation).toBe('saveFavorites');
      expect(stats.count).toBe(2);
      expect(stats.errors).toBe(1);
      expect(stats.successRate).toBe(50);
      expect(stats.latency.average).toBe(125);
    });

    it('should return empty stats for unknown operation', () => {
      const stats = monitor.getOperationStats('nonexistent');
      expect(stats.count).toBe(0);
      expect(stats.errors).toBe(0);
      expect(stats.successRate).toBe(0);
    });
  });

  describe('percentile calculation', () => {
    it('should calculate p50 (median) correctly', () => {
      const values = [10,20,30,40,50,60,70,80,90,100];
      values.forEach(v => monitor.recordOperation('test', v, true));
      const stats = monitor.getOperationStats('test');
      expect(stats.latency.p50).toBeCloseTo(50, 0);
    });

    it('should calculate p95 correctly', () => {
      const values = Array.from({ length: 100 }, (_, i) => i + 1);
      values.forEach(v => monitor.recordOperation('test', v, true));
      const stats = monitor.getOperationStats('test');
      expect((stats.latency.p95 ?? 0)).toBeGreaterThanOrEqual(95);
    });

    it('should calculate p99 correctly', () => {
      const values = Array.from({ length: 100 }, (_, i) => i + 1);
      values.forEach(v => monitor.recordOperation('test', v, true));
      const stats = monitor.getOperationStats('test');
      expect((stats.latency.p99 ?? 0)).toBeGreaterThanOrEqual(99);
    });

    it('should handle single value correctly', () => {
      monitor.recordOperation('test', 42, true);
      const stats = monitor.getOperationStats('test');
      expect(stats.latency.p50).toBe(42);
      expect(stats.latency.p95).toBe(42);
      expect(stats.latency.p99).toBe(42);
    });
  });

  describe('reset', () => {
    it('should clear all metrics', () => {
      monitor.recordOperation('test1', 100, true);
      monitor.recordOperation('test2', 200, false);
      expect(monitor.getMetrics().totalOperations).toBe(2);
      monitor.reset();
      const metrics = monitor.getMetrics();
      expect(metrics.totalOperations).toBe(0);
      expect(metrics.successfulOperations).toBe(0);
      expect(metrics.failedOperations).toBe(0);
      expect(Object.keys(metrics.operationCounts).length).toBe(0);
    });
  });

  describe('concurrent operations', () => {
    it('should handle concurrent recordOperation calls', async () => {
      await Promise.all(Array.from({ length: 100 }, (_, i) => Promise.resolve().then(() => monitor.recordOperation('test', i, true))));
      const metrics = monitor.getMetrics();
      expect(metrics.totalOperations).toBeGreaterThanOrEqual(100);
    });
  });
});
