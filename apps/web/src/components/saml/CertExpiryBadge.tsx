import React from "react";

function daysUntil(dateIso?: string | null) {
  if (!dateIso) return null;
  const exp = new Date(dateIso).getTime();
  if (isNaN(exp)) return null;
  const now = Date.now();
  const diff = Math.ceil((exp - now) / (1000 * 60 * 60 * 24));
  return diff;
}

export function CertExpiryBadge({ notAfterIso }: { notAfterIso?: string | null }) {
  const days = daysUntil(notAfterIso);
  if (days == null) return <span title="No certificate expiry info">—</span>;

  let color = "#16a34a"; // green
  let label = `${days}d`;
  if (days <= 14) color = "#dc2626"; // red
  else if (days <= 30) color = "#f59e0b"; // amber

  return (
    <span style={{
      background: color, color: "white", padding: "2px 6px",
      borderRadius: 8, fontSize: 12
    }} title={`Certificate expires in ${days} day(s)`}>
      Cert: {label}
    </span>
  );
}

export default CertExpiryBadge;
