import React, { useEffect, useState } from "react";
import { CertExpiryBadge } from "./CertExpiryBadge";
import { SamlEnableToggle } from "./SamlEnableToggle";
import { ValidateAssertion } from "./ValidateAssertion";
import SamlTelemetryTile from "./SamlTelemetryTile";

export function SamlAdminPanel({ orgId }: { orgId: string }) {
  const [certExpiryIso, setCertExpiryIso] = useState<string | null>(null);

  // Optional: derive cert expiry from saml_configs.idp_metadata_xml using a simple regex (NotAfter="...") if available via API
  useEffect(() => { (async () => {
    try {
      const r = await fetch(`/api/saml/config?org_id=${encodeURIComponent(orgId)}`);
      const j = await r.json();
      const xml = String(j.idp_metadata_xml || '');
      const m = xml.match(/NotAfter="([^"]+)"/);
      setCertExpiryIso(m ? m[1] : null);
    } catch { setCertExpiryIso(null); }
  })(); }, [orgId]);

  return (
    <div>
      <div style={{ display: "flex", gap: 12, alignItems: "center" }}>
        <SamlEnableToggle orgId={orgId} />
        <CertExpiryBadge notAfterIso={certExpiryIso} />
        <a href={`/saml/${orgId}/metadata`} target="_blank" rel="noreferrer">SP Metadata</a>
        <button onClick={() => fetch(`/saml_refresh?org_id=${encodeURIComponent(orgId)}`)}>Refresh IdP Metadata</button>
      </div>
      <div style={{ marginTop: 16 }}>
        <ValidateAssertion orgId={orgId} />
      </div>
      <div style={{ marginTop: 16 }}>
        <SamlTelemetryTile orgId={orgId} />
      </div>
    </div>
  );
}

export default SamlAdminPanel;
