import { DashboardStorage, RecentDashboard, AnalyticsEvent, AnalyticsQuery, AnalyticsResult } from '../interfaces/IDashboardStorage';
import { StorageMonitor } from '../interfaces/IStorageMonitor';

export class MonitoredDashboardStorage implements DashboardStorage {
  constructor(private inner: DashboardStorage, private monitor: StorageMonitor) {}

  private async measure<T>(op: string, fn: () => Promise<T>, meta: Record<string, any> = {}): Promise<T> {
    const start = (typeof performance !== 'undefined' && performance.now) ? performance.now() : Date.now();
    let success = true;
    try {
      return await fn();
    } catch (e: any) {
      success = false;
      meta.error = e?.message ?? String(e);
      throw e;
    } finally {
      const end = (typeof performance !== 'undefined' && performance.now) ? performance.now() : Date.now();
      this.monitor.recordOperation(op, end - start, success, meta);
    }
  }

  saveFavorites(userId: string, dashboardIds: string[]): Promise<void> {
    return this.measure('saveFavorites', () => this.inner.saveFavorites(userId, dashboardIds), { userId, count: dashboardIds.length });
  }
  loadFavorites(userId: string): Promise<string[]> {
    return this.measure('loadFavorites', () => this.inner.loadFavorites(userId), { userId });
  }
  addFavorite(userId: string, dashboardId: string): Promise<void> {
    return this.measure('addFavorite', () => this.inner.addFavorite(userId, dashboardId), { userId, dashboardId });
  }
  removeFavorite(userId: string, dashboardId: string): Promise<void> {
    return this.measure('removeFavorite', () => this.inner.removeFavorite(userId, dashboardId), { userId, dashboardId });
  }

  saveRecents(userId: string, recents: RecentDashboard[]): Promise<void> {
    return this.measure('saveRecents', () => this.inner.saveRecents(userId, recents), { userId, count: recents.length });
  }
  loadRecents(userId: string, limit?: number): Promise<RecentDashboard[]> {
    return this.measure('loadRecents', () => this.inner.loadRecents(userId, limit), { userId, limit });
  }
  addRecent(userId: string, dashboard: RecentDashboard): Promise<void> {
    return this.measure('addRecent', () => this.inner.addRecent(userId, dashboard), { userId, dashboardId: dashboard.id });
  }

  saveCategories(userId: string, categories: Record<string, string[]>): Promise<void> {
    return this.measure('saveCategories', () => this.inner.saveCategories(userId, categories), { userId, count: Object.keys(categories).length });
  }
  loadCategories(userId: string): Promise<Record<string, string[]>> {
    return this.measure('loadCategories', () => this.inner.loadCategories(userId), { userId });
  }

  saveAnalyticsEvent(event: AnalyticsEvent): Promise<void> {
    return this.measure('saveAnalyticsEvent', () => this.inner.saveAnalyticsEvent(event), { type: event.type });
  }
  queryAnalytics(query: AnalyticsQuery): Promise<AnalyticsResult> {
    return this.measure('queryAnalytics', () => this.inner.queryAnalytics(query), { type: query.type });
  }

  clear(userId?: string): Promise<void> {
    return this.measure('clear', () => this.inner.clear(userId), { userId });
  }
}

export default MonitoredDashboardStorage;
