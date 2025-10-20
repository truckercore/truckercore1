/**
 * Feature Flags
 * Central configuration for feature toggles
 */

export const FEATURE_FLAGS = {
  // WebSocket Features
  REDIS_WEBSOCKET: process.env.ENABLE_REDIS_WEBSOCKET === 'true',
  WEBSOCKET_COMPRESSION: process.env.ENABLE_WS_COMPRESSION === 'true',
  WEBSOCKET_BINARY: process.env.ENABLE_WS_BINARY === 'true',

  // Database Features
  DATABASE_POOLING: process.env.ENABLE_DATABASE_POOLING === 'true',
  READ_REPLICAS: process.env.ENABLE_READ_REPLICAS === 'true',
  QUERY_CACHING: process.env.ENABLE_QUERY_CACHING === 'true',

  // API Features
  API_CACHING: process.env.ENABLE_API_CACHING === 'true',
  API_RATE_LIMITING: process.env.ENABLE_RATE_LIMITING === 'true',
  API_COMPRESSION: process.env.ENABLE_API_COMPRESSION === 'true',

  // Real-time Features
  REAL_TIME_SYNC: process.env.ENABLE_REAL_TIME_SYNC === 'true',
  OPTIMISTIC_UI: process.env.ENABLE_OPTIMISTIC_UI === 'true',
  CONFLICT_RESOLUTION: process.env.ENABLE_CONFLICT_RESOLUTION === 'true',

  // Analytics
  PERFORMANCE_TRACING: process.env.ENABLE_PERFORMANCE_TRACING === 'true',
  DETAILED_LOGGING: process.env.ENABLE_DETAILED_LOGGING === 'true',

  // UI Features
  INFINITE_SCROLL: process.env.ENABLE_INFINITE_SCROLL === 'true',
  VIRTUAL_SCROLLING: process.env.ENABLE_VIRTUAL_SCROLLING === 'true',
  ADVANCED_FILTERS: process.env.ENABLE_ADVANCED_FILTERS === 'true',
} as const;

// Helper to check if feature is enabled
export function isFeatureEnabled(feature: keyof typeof FEATURE_FLAGS): boolean {
  return FEATURE_FLAGS[feature];
}

// Get all enabled features
export function getEnabledFeatures(): string[] {
  return Object.entries(FEATURE_FLAGS)
    .filter(([_, enabled]) => enabled)
    .map(([feature]) => feature);
}

// Get feature configuration for client
export function getClientFeatures() {
  // Only expose non-sensitive features to client
  return {
    realTimeSync: FEATURE_FLAGS.REAL_TIME_SYNC,
    optimisticUI: FEATURE_FLAGS.OPTIMISTIC_UI,
    infiniteScroll: FEATURE_FLAGS.INFINITE_SCROLL,
    virtualScrolling: FEATURE_FLAGS.VIRTUAL_SCROLLING,
    advancedFilters: FEATURE_FLAGS.ADVANCED_FILTERS,
  };
}

export default FEATURE_FLAGS;

// React hook for feature flags
export function useFeatureFlags() {
  return FEATURE_FLAGS;
}

