// Minimal dashboard storage abstraction for web (LocalStorage-based default)
export interface RecentDashboard { id: string; name?: string; accessedAt?: Date | string; }

export interface AnalyticsEvent { type: string; data?: any; timestamp?: string | Date }
export interface AnalyticsQuery { type?: string; from?: Date; to?: Date }
export interface AnalyticsResult { data: any[] }

export interface DashboardStorage {
  // Favorites
  saveFavorites(userId: string, dashboardIds: string[]): Promise<void>;
  loadFavorites(userId: string): Promise<string[]>;
  addFavorite(userId: string, dashboardId: string): Promise<void>;
  removeFavorite(userId: string, dashboardId: string): Promise<void>;

  // Recents
  saveRecents(userId: string, recents: RecentDashboard[]): Promise<void>;
  loadRecents(userId: string, limit?: number): Promise<RecentDashboard[]>;
  addRecent(userId: string, dashboard: RecentDashboard): Promise<void>;

  // Categories (collections)
  saveCategories(userId: string, categories: Record<string, string[]>): Promise<void>;
  loadCategories(userId: string): Promise<Record<string, string[]>>;

  // Analytics (lightweight)
  saveAnalyticsEvent(event: AnalyticsEvent): Promise<void>;
  queryAnalytics(query: AnalyticsQuery): Promise<AnalyticsResult>;

  // Lifecycle
  clear(userId?: string): Promise<void>;
}
