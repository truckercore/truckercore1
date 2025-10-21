// apps/web/pages/enterprise/reports/risk-corridors.tsx
import React from "react";
import { TopRiskCorridors } from "@/components/TopRiskCorridors";

// If your app exposes an enterprise org filter hook, use it here;
// otherwise render without org filter (component handles undefined).
// eslint-disable-next-line @typescript-eslint/no-unused-vars
function useEnterpriseOrgFilter(): string | undefined {
  // TODO: replace with your real selector if available
  return undefined;
}

export default function RiskCorridorsReport() {
  const orgId = useEnterpriseOrgFilter();
  return (
    <div style={{ padding: 16 }}>
      <TopRiskCorridors orgId={orgId ?? ""} />
    </div>
  );
}

// Force server-side rendering to avoid build-time data requirements
export async function getServerSideProps() {
  return { props: {} };
}
