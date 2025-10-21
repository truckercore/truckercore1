// apps/web/src/lib/entitlements.ts
export type Entitlements = {
  exportsMonthlyCap: number;
  roiReportsCap: number;
  corridorRefreshMins: number;
  retentionDaysSigned: number;
  boostedListings: number;
  activeChatThreads: number;
};

export function entitlementsForPlan(plan: string | null | undefined): Entitlements {
  switch (plan) {
    case "tc_enterprise":
    case "enterprise":
      return {
        exportsMonthlyCap: 1000,
        roiReportsCap: 50,
        corridorRefreshMins: 60,
        retentionDaysSigned: 730,
        boostedListings: 9999,
        activeChatThreads: 9999,
      };
    case "tc_pro":
    case "pro":
      return {
        exportsMonthlyCap: 200,
        roiReportsCap: 10,
        corridorRefreshMins: 240,
        retentionDaysSigned: 365,
        boostedListings: 50,
        activeChatThreads: 50,
      };
    default:
      return {
        exportsMonthlyCap: 20,
        roiReportsCap: 1,
        corridorRefreshMins: 1440,
        retentionDaysSigned: 90,
        boostedListings: 3,
        activeChatThreads: 3,
      };
  }
}
