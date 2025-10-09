import React, { useEffect, useState } from "react";

type Row = { t: string; ok: number; fail: number; p95_ms: number };

export function SamlTelemetryTile({ orgId }: { orgId: string }) {
  const [data, setData] = useState<Row[]>([]);
  useEffect(() => { (async () => {
    try {
      const r = await fetch(`/api/saml/telemetry?org_id=${encodeURIComponent(orgId)}`);
      const j = await r.json();
      setData(Array.isArray(j) ? j : []);
    } catch {
      setData([]);
    }
  })(); }, [orgId]);

  const last = data[0];
  return (
    <div style={{ border: "1px solid #e5e7eb", padding: 12, borderRadius: 8 }}>
      <h4>SAML Login (7d)</h4>
      <div>OK: {last?.ok ?? 0} • Fail: {last?.fail ?? 0} • p95: {last?.p95_ms ?? 0} ms</div>
    </div>
  );
}

export default SamlTelemetryTile;
