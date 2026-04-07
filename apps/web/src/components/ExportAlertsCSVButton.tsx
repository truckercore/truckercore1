import React from "react";

type Props = { orgId?: string; className?: string };

export const ExportAlertsCSVButton: React.FC<Props> = ({ orgId, className }) => {
  const onClick = () => {
    const base = "/api/export-alerts.csv";
    const url = orgId ? `${base}?org_id=${encodeURIComponent(orgId)}` : base;
    const a = document.createElement("a");
    a.href = url;
    a.download = "alerts.csv";
    document.body.appendChild(a);
    a.click();
    a.remove();
  };
  return (
    <button className={className ?? "btn btn-secondary"} onClick={onClick} aria-label="Export Alerts CSV">
      Export Alerts CSV
    </button>
  );
};
