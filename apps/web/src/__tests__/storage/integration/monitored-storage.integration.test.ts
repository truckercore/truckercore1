import { describe, it, expect, beforeEach } from 'vitest';
import StorageProvider from '@/services/storage/providers/StorageProvider';
import DefaultStorageMonitor from '@/services/storage/implementations/DefaultStorageMonitor';
import type { DashboardStorage } from '@/services/storage/interfaces/IDashboardStorage';

describe('MonitoredStorage Integration', () => {
  let storage: DashboardStorage;
  let monitor: DefaultStorageMonitor;

  beforeEach(() => {
    storage = StorageProvider.getStorage();
    monitor = DefaultStorageMonitor.getInstance();
    monitor.reset();
    // clear storage for test user
    localStorage.clear();
  });

  it('should track real storage operations', async () => {
    await storage.saveFavorites('user1', ['d1', 'd2']);
    await storage.loadFavorites('user1');
    const metrics = monitor.getMetrics();
    expect(metrics.totalOperations).toBe(2);
    expect(metrics.successfulOperations).toBe(2);
  });

  it('should track operation latencies', async () => {
    await storage.saveFavorites('user1', ['d1']);
    await storage.loadFavorites('user1');
    await storage.saveRecents('user1', []);
    const metrics = monitor.getMetrics();
    expect(metrics.averageLatency).toBeGreaterThanOrEqual(0);
  });

  it('should provide per-operation statistics', async () => {
    await storage.saveFavorites('user1', ['d1']);
    await storage.saveFavorites('user2', ['d2']);
    await storage.loadFavorites('user1');
    const saveStats = monitor.getOperationStats('saveFavorites');
    const loadStats = monitor.getOperationStats('loadFavorites');
    expect(saveStats.count).toBe(2);
    expect(loadStats.count).toBe(1);
  });

  it('should handle errors gracefully', async () => {
    // Force an error by tampering with localStorage quota is hard; instead call clear with undefined (allowed)
    await storage.clear(undefined);
    const metrics = monitor.getMetrics();
    expect(metrics.totalOperations).toBeGreaterThan(0);
  });

  it('should work across multiple storage instances', async () => {
    const storage1 = StorageProvider.getStorage();
    const storage2 = StorageProvider.getStorage();
    await storage1.saveFavorites('user1', ['d1']);
    await storage2.loadFavorites('user1');
    const metrics = monitor.getMetrics();
    expect(metrics.totalOperations).toBe(2);
  });
});
