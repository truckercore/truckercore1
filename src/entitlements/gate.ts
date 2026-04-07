// entitlements/gate.ts
// Adapter to align legacy app tiers with the canonical entitlements map (types/entitlements.ts)

import { resolveEntitlements, type PlanTier, type RoleKey, type Limits } from '../../types/entitlements';

export type Tier = 'basic' | 'premium' | 'ai';
export type Role =
  | 'driver'
  | 'ownerop'
  | 'fleet_admin'
  | 'dispatcher'
  | 'broker'
  | 'shipper';

export type UserEntitlements = {
  tier: Tier;
  ai_enabled?: boolean;
  roles: Role[];
  // Optional canonical fields when available
  role_key?: RoleKey;
  plan_tier?: PlanTier;
  addons?: string[];
};

// Minimal legacy feature gates kept for backward compatibility in UI only.
const gates: Record<string, (u: UserEntitlements) => boolean> = {
  // AI tier
  'driver.ai_route': (u) => !!u.ai_enabled,
  'ownerop.profit_tips': (u) => !!u.ai_enabled,
  'fleet.ai_capacity': (u) => !!u.ai_enabled,
  'broker.ai_matching': (u) => !!u.ai_enabled,

  // Premium and above
  'driver.load_board': (u) => u.tier !== 'basic',
  'fleet.analytics': (u) => u.tier !== 'basic',
};

export function hasFeature(u: UserEntitlements | null, featureKey: string): boolean {
  if (!u) return false;
  const fn = gates[featureKey];
  return fn ? fn(u) : false;
}

// --- Adapter mapping from legacy Tier -> PlanTier ---
export function mapTierToPlanTier(tier: Tier): PlanTier {
  switch (tier) {
    case 'basic': return 'free';
    case 'premium': return 'pro';
    // "ai" is a product bundle; map to pro by default and expect an AI add-on flag
    case 'ai': return 'pro';
    default: return 'free';
  }
}

// --- Server-side helpers ---
export type EffectiveEntitlements = { features: Record<string, boolean>; limits: Limits };

export function computeEffectiveEntitlements(params: {
  role: RoleKey;
  planTier: PlanTier;
  addons?: string[];
}): EffectiveEntitlements {
  const { role, planTier, addons = [] } = params;
  return resolveEntitlements(role, planTier, addons);
}

// Require a feature flag to be enabled; throws 403-like error object when denied.
export function requireFeature(ent: EffectiveEntitlements, featureKey: string) {
  if (ent.features[featureKey] !== true) {
    const err: any = new Error('forbidden_feature');
    err.status = 403;
    err.code = 'forbidden_feature';
    err.feature = featureKey;
    throw err;
  }
}

// Check numeric limit against current usage. Respects soft/hard caps.
export function requireLimit(ent: EffectiveEntitlements, limitKey: string, currentUsage: number) {
  const v = ent.limits[limitKey];
  if (v == null) return; // no limit configured
  if (typeof v === 'number') {
    if (currentUsage >= v) {
      const err: any = new Error('limit_exceeded');
      err.status = 429;
      err.code = 'limit_exceeded';
      err.limit = limitKey;
      err.hard = v;
      throw err;
    }
    return;
  }
  const soft = (v as any).soft as number | undefined;
  const hard = (v as any).hard as number | undefined;
  if (hard != null && currentUsage >= hard) {
    const err: any = new Error('limit_exceeded');
    err.status = 429;
    err.code = 'limit_exceeded';
    err.limit = limitKey;
    err.hard = hard;
    throw err;
  }
  if (soft != null && currentUsage >= soft) {
    const err: any = new Error('limit_soft_exceeded');
    err.status = 429;
    err.code = 'limit_soft_exceeded';
    err.limit = limitKey;
    err.soft = soft;
    throw err;
  }
}

// Convenience that takes legacy UserEntitlements and maps to effective entitlements
export function fromUser(u: UserEntitlements, opts?: { roleFallback?: RoleKey; addons?: string[] }): EffectiveEntitlements {
  const role = (u.role_key || opts?.roleFallback || 'driver') as RoleKey;
  const planTier = (u.plan_tier || mapTierToPlanTier(u.tier)) as PlanTier;
  const addons = (u.addons || opts?.addons || (u.ai_enabled ? ['ai_dispatcher_usage'] : []));
  return computeEffectiveEntitlements({ role, planTier, addons });
}
