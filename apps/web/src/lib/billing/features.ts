export const FEATURES = {
  ai_route_optimizer: ['owner_operator', 'fleet_manager', 'freight_broker', 'admin'],
  advanced_fleet_analytics: ['fleet_manager', 'admin'],
  broker_auto_matching: ['freight_broker', 'admin'],
  expense_analysis: ['owner_operator', 'admin'],
  hos_advanced: ['driver', 'owner_operator', 'fleet_manager', 'admin'],
  inspection_alerts: ['driver', 'owner_operator', 'fleet_manager', 'admin'],
  route_deviation: ['driver', 'owner_operator', 'fleet_manager', 'admin'],
} as const;

export type FeatureKey = keyof typeof FEATURES;
