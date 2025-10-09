import React, { useState, useEffect } from "react";

export function SamlEnableToggle({ orgId }: { orgId: string }) {
  const [enabled, setEnabled] = useState<boolean>(false);
  const [busy, setBusy] = useState(false);

  useEffect(() => { (async () => {
    try {
      const r = await fetch(`/api/saml/config?org_id=${encodeURIComponent(orgId)}`);
      const j = await r.json();
      setEnabled(!!j.enabled);
    } catch {
      setEnabled(false);
    }
  })(); }, [orgId]);

  async function toggle() {
    setBusy(true);
    try {
      await fetch(`/api/saml/config/enable`, {
        method: "POST", headers: { "content-type": "application/json" },
        body: JSON.stringify({ org_id: orgId, enabled: !enabled })
      });
      setEnabled(!enabled);
    } finally {
      setBusy(false);
    }
  }

  return (
    <div style={{ marginTop: 8 }}>
      <label>
        <input type="checkbox" checked={enabled} onChange={toggle} disabled={busy} />
        &nbsp;Enable SAML for this organization
      </label>
    </div>
  );
}

export default SamlEnableToggle;
