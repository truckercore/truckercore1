import { DashboardStorage, RecentDashboard, AnalyticsEvent, AnalyticsQuery, AnalyticsResult } from '../interfaces/IDashboardStorage';

// A lightweight LocalStorage-backed implementation for the web app
export class LocalStorageDashboardStorage implements DashboardStorage {
  private key(userId: string, suffix: string) {
    return `dash:${userId}:${suffix}`;
  }

  async saveFavorites(userId: string, dashboardIds: string[]): Promise<void> {
    localStorage.setItem(this.key(userId, 'favorites'), JSON.stringify(dashboardIds));
  }
  async loadFavorites(userId: string): Promise<string[]> {
    const raw = localStorage.getItem(this.key(userId, 'favorites'));
    if (!raw) return [];
    try { return JSON.parse(raw) as string[]; } catch { return []; }
  }
  async addFavorite(userId: string, dashboardId: string): Promise<void> {
    const favs = new Set(await this.loadFavorites(userId));
    favs.add(dashboardId);
    await this.saveFavorites(userId, Array.from(favs));
  }
  async removeFavorite(userId: string, dashboardId: string): Promise<void> {
    const favs = new Set(await this.loadFavorites(userId));
    favs.delete(dashboardId);
    await this.saveFavorites(userId, Array.from(favs));
  }

  async saveRecents(userId: string, recents: RecentDashboard[]): Promise<void> {
    localStorage.setItem(this.key(userId, 'recents'), JSON.stringify(recents));
  }
  async loadRecents(userId: string, limit = 10): Promise<RecentDashboard[]> {
    const raw = localStorage.getItem(this.key(userId, 'recents'));
    if (!raw) return [];
    try {
      const list = (JSON.parse(raw) as any[]).map((r) => ({...r, accessedAt: r.accessedAt}));
      return list.slice(0, limit);
    } catch {
      return [];
    }
  }
  async addRecent(userId: string, dashboard: RecentDashboard): Promise<void> {
    const list = await this.loadRecents(userId, Number.MAX_SAFE_INTEGER);
    const dedup = list.filter((r) => r.id !== dashboard.id);
    dedup.unshift({ ...dashboard, accessedAt: dashboard.accessedAt ?? new Date().toISOString() });
    while (dedup.length > 10) dedup.pop();
    await this.saveRecents(userId, dedup);
  }

  async saveCategories(userId: string, categories: Record<string, string[]>): Promise<void> {
    localStorage.setItem(this.key(userId, 'categories'), JSON.stringify(categories));
  }
  async loadCategories(userId: string): Promise<Record<string, string[]>> {
    const raw = localStorage.getItem(this.key(userId, 'categories'));
    if (!raw) return {};
    try { return JSON.parse(raw) as Record<string, string[]>; } catch { return {}; }
  }

  async saveAnalyticsEvent(event: AnalyticsEvent): Promise<void> {
    const key = `dash:analytics`;
    const raw = localStorage.getItem(key);
    const arr = raw ? (JSON.parse(raw) as any[]) : [];
    arr.push({ ...event, timestamp: (event.timestamp ?? new Date().toISOString())});
    localStorage.setItem(key, JSON.stringify(arr));
  }
  async queryAnalytics(_query: AnalyticsQuery): Promise<AnalyticsResult> {
    const key = `dash:analytics`;
    const raw = localStorage.getItem(key);
    const arr = raw ? (JSON.parse(raw) as any[]) : [];
    return { data: arr };
  }

  async clear(userId?: string): Promise<void> {
    if (!userId) {
      Object.keys(localStorage)
        .filter((k) => k.startsWith('dash:'))
        .forEach((k) => localStorage.removeItem(k));
      return;
    }
    Object.keys(localStorage)
      .filter((k) => k.startsWith(`dash:${userId}:`))
      .forEach((k) => localStorage.removeItem(k));
  }
}

export default LocalStorageDashboardStorage;
