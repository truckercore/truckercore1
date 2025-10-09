// TypeScript
import React from "react";

export function InsurerExportButtons({ day, orgId }: { day: string; orgId?: string }) {
  const go = (action: "export_csv" | "export_pdf") => {
    const base = "/api/kpi-export";
    const u = new URL(base, window.location.origin);
    u.searchParams.set("action", action);
    u.searchParams.set("day", day);
    if (orgId) u.searchParams.set("org_id", orgId);
    window.location.href = u.toString();
  };
  return (
    <div style={{ display: "flex", gap: 8 }}>
      <button className="btn btn-secondary" onClick={() => go("export_csv")}>
        Download CSV
      </button>
      <button className="btn" onClick={() => go("export_pdf")}>
        Download PDF
      </button>
    </div>
  );
}
