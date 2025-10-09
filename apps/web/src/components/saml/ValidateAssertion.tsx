import React, { useState } from "react";

export function ValidateAssertion({ orgId }: { orgId: string }) {
  const [xml, setXml] = useState("");
  const [result, setResult] = useState<any>(null);
  const [busy, setBusy] = useState(false);

  async function onValidate() {
    setBusy(true);
    try {
      const r = await fetch(`/api/saml/dryrun?org_id=${encodeURIComponent(orgId)}`, {
        method: "POST",
        headers: { "content-type": "application/xml" },
        body: xml
      });
      const j = await r.json();
      setResult({ ok: r.ok, ...j });
    } catch (e: any) {
      setResult({ ok: false, error: String(e?.message || e) });
    } finally {
      setBusy(false);
    }
  }

  return (
    <div>
      <h4>Validate Assertion (Dry-Run)</h4>
      <textarea
        placeholder="Paste SAML Assertion XML here"
        value={xml}
        onChange={e => setXml(e.target.value)}
        rows={8}
        style={{ width: "100%", fontFamily: "monospace" }}
      />
      <div style={{ marginTop: 8 }}>
        <button onClick={onValidate} disabled={busy || !xml.trim()}>
          {busy ? "Validating..." : "Validate"}
        </button>
      </div>
      {result && (
        <pre style={{ background: "#f8fafc", padding: 8, marginTop: 8 }}>
{JSON.stringify(result, null, 2)}
        </pre>
      )}
    </div>
  );
}

export default ValidateAssertion;
