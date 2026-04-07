import React from "react";
import { useEntitlements } from "@/hooks/useEntitlements";

export const UsageProgress: React.FC<{ kind: "alerts_csv" | "roi_pdf"; used: number }> = ({ kind, used }) => {
  const ent = useEntitlements();
  const cap = kind === "alerts_csv" ? ent.exportsMonthlyCap : ent.roiReportsCap;
  const pct = Math.min(100, (used / cap) * 100);
  const color = pct < 75 ? "#2E7D32" : pct < 90 ? "#F9A825" : "#C62828";

  return (
    <div style={{ marginBottom: 12 }}>
      <div style={{ display: "flex", justifyContent: "space-between", marginBottom: 4 }}>
        <span style={{ fontSize: 12, opacity: 0.8 }}>
          {kind === "alerts_csv" ? "CSV Exports" : "ROI Reports"} this month
        </span>
        <span style={{ fontSize: 12, fontWeight: 600 }}>
          {used} / {cap}
        </span>
      </div>
      <div style={{ background: "#e0e0e0", borderRadius: 4, height: 6, overflow: "hidden" }}>
        <div style={{ background: color, width: `${pct}%`, height: "100%" }} />
      </div>
      {pct >= 90 && (
        <div style={{ fontSize: 12, color, marginTop: 4 }}>
          Approaching limit. <a href="/upgrade">Upgrade for more.</a>
        </div>
      )}
    </div>
  );
};
