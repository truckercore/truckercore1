export interface IntegrationFeatureFlags {
  // Per-vendor toggles
  datEnabled: boolean;
  trimbleEnabled: boolean;
  samsaraEnabled: boolean;

  // Per-operation toggles
  datWriteEnabled: boolean;
  trimbleRoutingEnabled: boolean;
  samsaraRealtimeEnabled: boolean;

  // Heavy/expensive features
  datBulkSearchEnabled: boolean;
  trimbleGeofencingEnabled: boolean;
  samsaraHistoricalDataEnabled: boolean;

  // Emergency kill switches
  allWriteOperationsEnabled: boolean;
  heavyEndpointsEnabled: boolean;
  highCostFeaturesEnabled: boolean;

  // Per-tenant overrides
  tenantOverrides?: Record<string, Partial<IntegrationFeatureFlags>>;
}

export const defaultIntegrationFlags: IntegrationFeatureFlags = {
  datEnabled: true,
  trimbleEnabled: true,
  samsaraEnabled: true,

  datWriteEnabled: true,
  trimbleRoutingEnabled: true,
  samsaraRealtimeEnabled: true,

  datBulkSearchEnabled: true,
  trimbleGeofencingEnabled: true,
  samsaraHistoricalDataEnabled: true,

  allWriteOperationsEnabled: true,
  heavyEndpointsEnabled: true,
  highCostFeaturesEnabled: true,
};

export class IntegrationFlagManager {
  private flags: IntegrationFeatureFlags;

  constructor(initialFlags: IntegrationFeatureFlags = defaultIntegrationFlags) {
    this.flags = { ...initialFlags };
  }

  updateFlags(newFlags: Partial<IntegrationFeatureFlags>): void {
    this.flags = { ...this.flags, ...newFlags };
  }

  isEnabled(flagName: keyof IntegrationFeatureFlags, tenantId?: string): boolean {
    // Check tenant-specific override first
    if (tenantId && this.flags.tenantOverrides?.[tenantId]) {
      const override = this.flags.tenantOverrides[tenantId][flagName];
      if (override !== undefined) {
        return override as boolean;
      }
    }

    // Fall back to global flag
    return this.flags[flagName] as boolean;
  }

  canWriteToVendor(vendor: 'DAT' | 'TRIMBLE' | 'SAMSARA', tenantId?: string): boolean {
    if (!this.isEnabled('allWriteOperationsEnabled', tenantId)) {
      return false;
    }

    switch (vendor) {
      case 'DAT':
        return this.isEnabled('datWriteEnabled', tenantId);
      case 'TRIMBLE':
        return true; // Trimble is typically read-only
      case 'SAMSARA':
        return true; // Samsara write ops are rare
      default:
        return false;
    }
  }

  canUseHeavyEndpoint(_endpoint: string, tenantId?: string): boolean {
    return this.isEnabled('heavyEndpointsEnabled', tenantId);
  }

  canUseHighCostFeature(_feature: string, tenantId?: string): boolean {
    return this.isEnabled('highCostFeaturesEnabled', tenantId);
  }

  setTenantOverride(
    tenantId: string,
    overrides: Partial<IntegrationFeatureFlags>,
  ): void {
    if (!this.flags.tenantOverrides) {
      this.flags.tenantOverrides = {};
    }
    this.flags.tenantOverrides[tenantId] = {
      ...this.flags.tenantOverrides[tenantId],
      ...overrides,
    };
  }

  getFlags(tenantId?: string): IntegrationFeatureFlags {
    if (tenantId && this.flags.tenantOverrides?.[tenantId]) {
      return { ...this.flags, ...this.flags.tenantOverrides[tenantId] } as IntegrationFeatureFlags;
    }
    return { ...this.flags };
  }
}
