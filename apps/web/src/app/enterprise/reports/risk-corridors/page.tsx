import React from "react";
import { TopRiskCorridors } from "@/components/TopRiskCorridors";

export const dynamic = 'force-dynamic';

export default function RiskCorridorsReportPage() {
  return (
    <div style={{ padding: 16 }}>
      <TopRiskCorridors orgId="" />
    </div>
  );
}
