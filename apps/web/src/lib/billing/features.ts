import type { AppRole, AccessProfile } from '@/lib/auth/access';
import { hasPremiumRoleAccess } from '@/lib/auth/access';

export const FEATURES = {
  ai_route_optimizer: ['owner_operator', 'fleet_manager', 'freight_broker', 'admin'],
  advanced_fleet_analytics: ['fleet_manager', 'admin'],
  broker_auto_matching: ['freight_broker', 'admin'],
  expense_analysis: ['owner_operator', 'admin'],
  hos_advanced: ['driver', 'owner_operator', 'fleet_manager', 'admin'],
  premium_gps_overlays: ['driver', 'owner_operator', 'fleet_manager', 'freight_broker', 'admin'],
} as const satisfies Record<string, AppRole[]>;

export type FeatureKey = keyof typeof FEATURES;

export function canUseFeature(
  profile: AccessProfile | null | undefined,
  feature: FeatureKey
): boolean {
  return hasPremiumRoleAccess(profile, FEATURES[feature]);
}
