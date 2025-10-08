import { describe, it, expect, beforeEach, vi } from 'vitest';
import { MonitoredDashboardStorage } from '@/services/storage/decorators/MonitoredDashboardStorage';
import DefaultStorageMonitor from '@/services/storage/implementations/DefaultStorageMonitor';
import type { DashboardStorage, AnalyticsEvent, AnalyticsQuery } from '@/services/storage/interfaces/IDashboardStorage';

class MockDashboardStorage implements DashboardStorage {
  saveFavorites = vi.fn().mockResolvedValue(undefined);
  loadFavorites = vi.fn().mockResolvedValue<string[]>([]);
  saveRecents = vi.fn().mockResolvedValue(undefined);
  loadRecents = vi.fn().mockResolvedValue<any[]>([]);
  saveCategories = vi.fn().mockResolvedValue(undefined);
  loadCategories = vi.fn().mockResolvedValue<Record<string, string[]>>({});
  saveAnalyticsEvent = vi.fn().mockResolvedValue(undefined);
  queryAnalytics = vi.fn().mockResolvedValue({ data: [] });
  clear = vi.fn().mockResolvedValue(undefined);
  addFavorite = vi.fn().mockResolvedValue(undefined);
  removeFavorite = vi.fn().mockResolvedValue(undefined);
  addRecent = vi.fn().mockResolvedValue(undefined);
}

describe('MonitoredDashboardStorage', () => {
  let mockStorage: MockDashboardStorage;
  let monitor: DefaultStorageMonitor;
  let monitored: MonitoredDashboardStorage;

  beforeEach(() => {
    mockStorage = new MockDashboardStorage();
    monitor = DefaultStorageMonitor.getInstance();
    monitor.reset();
    monitored = new MonitoredDashboardStorage(mockStorage as unknown as DashboardStorage, monitor);
  });

  describe('transparency', () => {
    it('should delegate saveFavorites to underlying storage', async () => {
      await monitored.saveFavorites('user1', ['d1', 'd2']);
      expect(mockStorage.saveFavorites).toHaveBeenCalledWith('user1', ['d1', 'd2']);
    });

    it('should return result from underlying storage', async () => {
      mockStorage.loadFavorites.mockResolvedValue(['d1', 'd2', 'd3']);
      const result = await monitored.loadFavorites('user1');
      expect(result).toEqual(['d1', 'd2', 'd3']);
    });

    it('should preserve errors from underlying storage', async () => {
      const error = new Error('Storage failure');
      mockStorage.saveFavorites.mockRejectedValue(error);
      await expect(monitored.saveFavorites('user1', [])).rejects.toThrow('Storage failure');
    });
  });

  describe('metrics tracking', () => {
    it('should record successful operation', async () => {
      await monitored.saveFavorites('user1', ['d1']);
      const metrics = monitor.getMetrics();
      expect(metrics.totalOperations).toBe(1);
      expect(metrics.successfulOperations).toBe(1);
      expect(metrics.failedOperations).toBe(0);
    });

    it('should record failed operation', async () => {
      mockStorage.loadFavorites.mockRejectedValue(new Error('Load failed'));
      await expect(monitored.loadFavorites('user1')).rejects.toThrow('Load failed');
      const metrics = monitor.getMetrics();
      expect(metrics.totalOperations).toBe(1);
      expect(metrics.successfulOperations).toBe(0);
      expect(metrics.failedOperations).toBe(1);
    });

    it('should track operation duration', async () => {
      mockStorage.loadRecents.mockImplementation(() => new Promise(resolve => setTimeout(() => resolve([]), 100)));
      await monitored.loadRecents('user1');
      const stats = monitor.getOperationStats('loadRecents');
      expect(stats.latency.average).toBeGreaterThanOrEqual(100);
    });

    it('should track multiple operations', async () => {
      await monitored.saveFavorites('user1', ['d1']);
      await monitored.loadFavorites('user1');
      await monitored.saveRecents('user1', []);
      await monitored.loadRecents('user1');
      const metrics = monitor.getMetrics();
      expect(metrics.totalOperations).toBe(4);
      expect(metrics.operationCounts.saveFavorites).toBe(1);
      expect(metrics.operationCounts.loadFavorites).toBe(1);
      expect(metrics.operationCounts.saveRecents).toBe(1);
      expect(metrics.operationCounts.loadRecents).toBe(1);
    });

    it('should track same operation multiple times', async () => {
      await monitored.saveFavorites('user1', ['d1']);
      await monitored.saveFavorites('user2', ['d2']);
      await monitored.saveFavorites('user3', ['d3']);
      const stats = monitor.getOperationStats('saveFavorites');
      expect(stats.count).toBe(3);
    });
  });

  describe('metadata tracking', () => {
    it('should include userId in metadata', async () => {
      const spy = vi.spyOn(monitor, 'recordOperation');
      await monitored.saveFavorites('user1', ['d1']);
      expect(spy).toHaveBeenCalledWith('saveFavorites', expect.any(Number), true, expect.objectContaining({ userId: 'user1' }));
    });

    it('should include array length in metadata', async () => {
      const spy = vi.spyOn(monitor, 'recordOperation');
      await monitored.saveFavorites('user1', ['d1', 'd2', 'd3']);
      expect(spy).toHaveBeenCalledWith('saveFavorites', expect.any(Number), true, expect.objectContaining({ count: 3 }));
    });

    it('should include error message in metadata on failure', async () => {
      const spy = vi.spyOn(monitor, 'recordOperation');
      mockStorage.saveFavorites.mockRejectedValue(new Error('Quota exceeded'));
      await expect(monitored.saveFavorites('user1', [])).rejects.toThrow();
      expect(spy).toHaveBeenCalledWith('saveFavorites', expect.any(Number), false, expect.objectContaining({ error: 'Quota exceeded' }));
    });
  });

  describe('all storage methods', () => {
    it('should monitor loadFavorites', async () => {
      await monitored.loadFavorites('user1');
      const stats = monitor.getOperationStats('loadFavorites');
      expect(stats.count).toBe(1);
    });

    it('should monitor saveRecents', async () => {
      await monitored.saveRecents('user1', []);
      const stats = monitor.getOperationStats('saveRecents');
      expect(stats.count).toBe(1);
    });

    it('should monitor loadRecents', async () => {
      await monitored.loadRecents('user1');
      const stats = monitor.getOperationStats('loadRecents');
      expect(stats.count).toBe(1);
    });

    it('should monitor saveCategories', async () => {
      await monitored.saveCategories('user1', {});
      const stats = monitor.getOperationStats('saveCategories');
      expect(stats.count).toBe(1);
    });

    it('should monitor loadCategories', async () => {
      await monitored.loadCategories('user1');
      const stats = monitor.getOperationStats('loadCategories');
      expect(stats.count).toBe(1);
    });

    it('should monitor saveAnalyticsEvent', async () => {
      const event = { type: 'test', data: {} } as AnalyticsEvent;
      await monitored.saveAnalyticsEvent(event);
      const stats = monitor.getOperationStats('saveAnalyticsEvent');
      expect(stats.count).toBe(1);
    });

    it('should monitor queryAnalytics', async () => {
      const query = { type: 'test' } as AnalyticsQuery;
      await monitored.queryAnalytics(query);
      const stats = monitor.getOperationStats('queryAnalytics');
      expect(stats.count).toBe(1);
    });

    it('should monitor clear', async () => {
      await monitored.clear('user1');
      const stats = monitor.getOperationStats('clear');
      expect(stats.count).toBe(1);
    });
  });

  describe('performance', () => {
    it('should have minimal overhead', async () => {
      const directStart = performance.now();
      await mockStorage.loadFavorites('user1');
      const directDuration = performance.now() - directStart;

      const monitoredStart = performance.now();
      await monitored.loadFavorites('user1');
      const monitoredDuration = performance.now() - monitoredStart;

      const overhead = monitoredDuration - directDuration;
      expect(overhead).toBeLessThan(5);
    });
  });
});
