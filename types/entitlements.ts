// types/entitlements.ts
// Entitlements configuration for all roles/tiers and add-ons.
// Use as the canonical map for enforcement and UI gating.

export type LimitValue = number | { soft?: number; hard?: number };
export type Limits = Record<string, LimitValue>;

export type PlanTier = 'free' | 'pro' | 'enterprise';
export type RoleKey = 'driver' | 'fleet' | 'ownerop' | 'broker';

export interface PlanEntitlements {
  plan_id: string; // internal key, e.g., 'driver_pro'
  role: RoleKey;
  tier: PlanTier;
  enabled: boolean;
  features: Record<string, boolean>;
  limits: Limits;
  billing?: {
    stripe_price_id?: string; // filled at deploy
    unit?: 'seat' | 'truck' | 'org';
    platform_min_monthly_usd?: number; // enforce in billing layer
    tiered?: Array<{ upto?: number; price_per_unit_usd: number }>;
  };
  notes?: string;
}

export interface AddOnEntitlement {
  addon_id: string; // e.g., 'ai_dispatcher_usage'
  enabled: boolean;
  features: Record<string, boolean>;
  limits: Limits; // usage counters and caps
  billing?: {
    stripe_price_id?: string;
    kind: 'recurring' | 'usage';
    unit_label?: string; // e.g., '1k_tokens'
    tiers?: Array<{ upto?: number; unit_price_usd: number }>;
    monthly_flat_usd?: number;
    setup_fee_usd?: number;
  };
  notes?: string;
}

export const ENTITLEMENTS: {
  roles: Record<RoleKey, Record<PlanTier, PlanEntitlements>>;
  addons: Record<string, AddOnEntitlement>;
} = {
  roles: {
    driver: {
      free: {
        plan_id: 'driver_free',
        role: 'driver',
        tier: 'free',
        enabled: true,
        features: {
          gps_basic: true,
          load_browse: true,
          offline_maps: false,
          hos_integration: false,
          support_priority: false,
        },
        limits: {
          trucks: 1,
          ai_tokens_month: 0,
          analytics_history_days: 7,
        },
        notes: 'Seed the network; upsell to Pro for HOS + offline maps.',
      },
      pro: {
        plan_id: 'driver_pro',
        role: 'driver',
        tier: 'pro',
        enabled: true,
        features: {
          gps_basic: true,
          load_browse: true,
          offline_maps: true,
          hos_integration: true,
          support_priority: true,
        },
        limits: {
          trucks: 1,
          ai_tokens_month: { soft: 3000000 }, // 3M tokens if flat tier purchased; base can be 0 without add-on
          analytics_history_days: 30,
        },
        billing: {
          unit: 'seat',
          // stripe_price_id to be set per A/B group ($9/$12/$15)
        },
        notes: 'Driver must-haves: HOS + offline maps.',
      },
      enterprise: {
        plan_id: 'driver_enterprise',
        role: 'driver',
        tier: 'enterprise',
        enabled: true,
        features: {
          gps_basic: true,
          load_browse: true,
          offline_maps: true,
          hos_integration: true,
          support_priority: true,
          managed_by_fleet: true,
          sso: true,
          enforced_policies: true,
        },
        limits: {
          trucks: 1,
          ai_tokens_month: { soft: 10000000 }, // governed by fleet contract
          analytics_history_days: 90,
        },
        billing: {
          unit: 'seat',
        },
        notes: 'Provisioned via Fleet enterprise contracts.',
      },
    },

    fleet: {
      free: {
        plan_id: 'fleet_free',
        role: 'fleet',
        tier: 'free',
        enabled: true,
        features: {
          dispatch_basic: true,
          analytics_basic: true,
          invoicing: false,
          webhooks_receive: false,
          api_access: false,
          sso_scim: false,
          white_label: false,
        },
        limits: {
          trucks: 5,
          users: 10,
          active_loads: 20,
          chat_threads_active: 3,
          analytics_history_days: 30,
        },
        notes: 'Good for very small fleets; gates incentivize upgrade.',
      },
      pro: {
        plan_id: 'fleet_pro',
        role: 'fleet',
        tier: 'pro',
        enabled: true,
        features: {
          dispatch_basic: true,
          analytics_full: true,
          invoicing: true,
          webhooks_receive: true, // limited by add-on tiers if purchased
          api_access: true,
          sso_scim: false,
          white_label: false,
        },
        limits: {
          trucks: 50,
          users: 100,
          active_loads: { soft: 500, hard: 2000 },
          chat_threads_active: { soft: 50, hard: 200 },
          api_calls_month: { soft: 100000, hard: 300000 },
          webhooks_month: { soft: 10000, hard: 50000 },
          analytics_history_days: 180,
          platform_min_monthly_usd: 99, // mirror for enforcement UI; actual enforcement in billing
        },
        billing: {
          unit: 'truck',
          platform_min_monthly_usd: 99,
          // price_per_unit set via Stripe ($10) with A/B $8/$12 tests
        },
        notes: 'Ensure platform minimum is enforced in billing.',
      },
      enterprise: {
        plan_id: 'fleet_enterprise',
        role: 'fleet',
        tier: 'enterprise',
        enabled: true,
        features: {
          dispatch_basic: true,
          analytics_full: true,
          invoicing: true,
          webhooks_receive: true,
          api_access: true,
          sso_scim: true,
          white_label: true,
          audit_exports: true,
          data_residency_controls: true,
        },
        limits: {
          trucks: { soft: 200, hard: 100000 },
          users: { soft: 500, hard: 5000 },
          active_loads: { soft: 5000, hard: 20000 },
          chat_threads_active: { soft: 500, hard: 5000 },
          api_calls_month: { soft: 1000000, hard: 5000000 },
          webhooks_month: { soft: 200000, hard: 2000000 },
          analytics_history_days: 365,
          platform_min_monthly_usd: 1500,
        },
        billing: {
          unit: 'truck',
          platform_min_monthly_usd: 1500,
          tiered: [
            { upto: 200, price_per_unit_usd: 12 },
            { upto: undefined, price_per_unit_usd: 8 }, // 201+
          ],
        },
        notes: 'Contract pricing; includes SSO/SCIM and white-label.',
      },
    },

    ownerop: {
      free: {
        plan_id: 'ownerop_free',
        role: 'ownerop',
        tier: 'free',
        enabled: true,
        features: {
          gps_basic: true,
          load_matching: true,
          expense_tracker: false,
          compliance_automation: false,
          ai_dispatcher_access: false,
          permissions_advanced: false,
        },
        limits: {
          seats: 1,
          trucks: 1,
          analytics_history_days: 30,
        },
      },
      pro: {
        plan_id: 'ownerop_pro',
        role: 'ownerop',
        tier: 'pro',
        enabled: true,
        features: {
          gps_basic: true,
          load_matching: true,
          expense_tracker: true,
          compliance_automation: true,
          ai_dispatcher_access: true, // usage capped by add-on
          permissions_advanced: false,
        },
        limits: {
          seats: 1,
          trucks: 1,
          ai_tokens_month: { soft: 3000000 },
          analytics_history_days: 180,
        },
        billing: {
          unit: 'seat',
          // Stripe price $24 (A/B $19/$29)
        },
      },
      enterprise: {
        plan_id: 'small_carrier', // fleet-lite for multi-entity owner-ops
        role: 'ownerop',
        tier: 'enterprise',
        enabled: true,
        features: {
          expense_tracker: true,
          compliance_automation: true,
          ai_dispatcher_access: true,
          permissions_advanced: true,
          multi_entity: true,
        },
        limits: {
          seats: { soft: 10, hard: 50 },
          trucks: { soft: 10, hard: 100 },
          ai_tokens_month: { soft: 8000000, hard: 20000000 },
          analytics_history_days: 365,
          platform_min_monthly_usd: 199,
        },
        billing: {
          unit: 'seat',
          platform_min_monthly_usd: 199,
          // $39/seat
        },
        notes: 'Positioned as “Small Carrier” package.',
      },
    },

    broker: {
      free: {
        plan_id: 'broker_free',
        role: 'broker',
        tier: 'free',
        enabled: true,
        features: {
          post_loads: true,
          marketplace_publish: true,
          chat_basic: true,
          analytics_basic: true,
          ai_match_suggestions: false,
          negotiation: false,
          compliance_automation: false,
          esign: false,
          webhooks_publish: false,
          api_access: false,
        },
        limits: {
          active_loads: 20,
          chat_threads_active: 3,
          boosted_listings_month: 3,
          analytics_history_days: 30,
        },
      },
      pro: {
        plan_id: 'broker_pro',
        role: 'broker',
        tier: 'pro',
        enabled: true,
        features: {
          post_loads: true,
          marketplace_publish: true,
          chat_basic: true,
          analytics_full: true,
          ai_match_suggestions: true,
          negotiation: true,
          compliance_automation: true,
          esign: true,
          webhooks_publish: true, // higher tiers via add-on
          api_access: true,
        },
        limits: {
          active_loads: { soft: 500, hard: 2000 },
          chat_threads_active: { soft: 100, hard: 500 },
          boosted_listings_month: { soft: 100, hard: 1000 },
          api_calls_month: { soft: 200000, hard: 1000000 },
          webhooks_month: { soft: 20000, hard: 200000 },
          analytics_history_days: 365,
        },
        billing: {
          unit: 'org',
          // Stripe price $199 (A/B $149/$249)
        },
      },
      enterprise: {
        plan_id: 'broker_enterprise',
        role: 'broker',
        tier: 'enterprise',
        enabled: true,
        features: {
          post_loads: true,
          marketplace_publish: true,
          chat_basic: true,
          analytics_full: true,
          ai_match_suggestions: true,
          negotiation: true,
          compliance_automation: true,
          esign: true,
          webhooks_publish: true,
          api_access: true,
          sso_scim: true,
          white_label: true,
          audit_exports: true,
        },
        limits: {
          active_loads: { soft: 5000, hard: 20000 },
          chat_threads_active: { soft: 1000, hard: 10000 },
          boosted_listings_month: { soft: 1000, hard: 10000 },
          api_calls_month: { soft: 1000000, hard: 5000000 },
          webhooks_month: { soft: 200000, hard: 2000000 },
          analytics_history_days: 1095, // 3 years
          platform_min_monthly_usd: 1500,
        },
        billing: {
          unit: 'org',
          platform_min_monthly_usd: 1500,
        },
        notes: 'Custom pricing; include SLAs and onboarding.',
      },
    },
  },

  addons: {
    // AI dispatcher usage-based
    ai_dispatcher_usage: {
      addon_id: 'ai_dispatcher_usage',
      enabled: true,
      features: { ai_dispatcher_access: true },
      limits: {
        ai_tokens_month: { soft: 0 }, // usage-only; meters increment here
      },
      billing: {
        kind: 'usage',
        unit_label: '1k_tokens',
        tiers: [
          { upto: undefined, unit_price_usd: 0.03 }, // flat $0.03 per 1k
        ],
      },
      notes: 'Pure usage metering for AI tokens.',
    },

    // AI dispatcher flat tiers
    ai_dispatcher_flat_99: {
      addon_id: 'ai_dispatcher_flat_99',
      enabled: true,
      features: { ai_dispatcher_access: true },
      limits: { ai_tokens_month: { soft: 3000000 } }, // 3M
      billing: { kind: 'recurring', monthly_flat_usd: 99 },
      notes: 'Includes 3M tokens; overage via usage add-on if combined.',
    },
    ai_dispatcher_flat_199: {
      addon_id: 'ai_dispatcher_flat_199',
      enabled: true,
      features: { ai_dispatcher_access: true },
      limits: { ai_tokens_month: { soft: 8000000 } }, // 8M
      billing: { kind: 'recurring', monthly_flat_usd: 199 },
    },
    ai_dispatcher_flat_399: {
      addon_id: 'ai_dispatcher_flat_399',
      enabled: true,
      features: { ai_dispatcher_access: true },
      limits: { ai_tokens_month: { soft: 20000000 } }, // 20M
      billing: { kind: 'recurring', monthly_flat_usd: 399 },
    },

    // Webhooks/API rate limit upgrades
    webhooks_api_149: {
      addon_id: 'webhooks_api_149',
      enabled: true,
      features: { webhooks_publish: true, api_access: true },
      limits: { webhooks_month: { soft: 100000 }, api_calls_month: { soft: 300000 } },
      billing: { kind: 'recurring', monthly_flat_usd: 149 },
    },
    webhooks_api_299: {
      addon_id: 'webhooks_api_299',
      enabled: true,
      features: { webhooks_publish: true, api_access: true },
      limits: { webhooks_month: { soft: 300000 }, api_calls_month: { soft: 800000 } },
      billing: { kind: 'recurring', monthly_flat_usd: 299 },
    },
    webhooks_api_499: {
      addon_id: 'webhooks_api_499',
      enabled: true,
      features: { webhooks_publish: true, api_access: true },
      limits: { webhooks_month: { soft: 1000000 }, api_calls_month: { soft: 2000000 } },
      billing: { kind: 'recurring', monthly_flat_usd: 499 },
    },

    // White-label
    white_label: {
      addon_id: 'white_label',
      enabled: true,
      features: { white_label: true },
      limits: {},
      billing: { kind: 'recurring', monthly_flat_usd: 199, setup_fee_usd: 499 },
    },

    // Compliance + E-Sign bundle
    compliance_esign: {
      addon_id: 'compliance_esign',
      enabled: true,
      features: { compliance_automation: true, esign: true },
      limits: {},
      billing: { kind: 'recurring', monthly_flat_usd: 149 },
    },

    // Priority support / SLA
    priority_support: {
      addon_id: 'priority_support',
      enabled: true,
      features: { support_priority: true },
      limits: {},
      billing: { kind: 'recurring', monthly_flat_usd: 299 },
    },
  },
};

// Helper to get plan entitlements by role+tier
export function getPlan(role: RoleKey, tier: PlanTier): PlanEntitlements {
  return ENTITLEMENTS.roles[role][tier];
}

// Merge plan and active add-ons into a single effective entitlement object.
export function resolveEntitlements(
  role: RoleKey,
  tier: PlanTier,
  activeAddons: string[] = []
): { features: Record<string, boolean>; limits: Limits } {
  const base = getPlan(role, tier);
  const features: Record<string, boolean> = { ...base.features };
  const limits: Limits = { ...base.limits };

  for (const addonId of activeAddons) {
    const a = ENTITLEMENTS.addons[addonId];
    if (!a || !a.enabled) continue;
    Object.assign(features, a.features);
    for (const [k, v] of Object.entries(a.limits)) {
      const existing = limits[k];
      if (existing == null) {
        limits[k] = v;
      } else if (typeof existing === 'number' && typeof v === 'number') {
        limits[k] = existing + v;
      } else {
        // Merge soft/hard by summing soft and taking max for hard where present
        const toObj = (x: LimitValue) =>
          typeof x === 'number' ? ({ soft: x as number } as { soft?: number; hard?: number }) : (x as any);
        const e = toObj(existing);
        const n = toObj(v);
        limits[k] = {
          soft: (e.soft ?? 0) + (n.soft ?? 0),
          hard:
            e.hard != null || n.hard != null
              ? Math.max(e.hard ?? 0, n.hard ?? 0)
              : undefined,
        } as any;
      }
    }
  }

  return { features, limits };
}
