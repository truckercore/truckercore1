// apps/web/src/components/SamlRefresh.tsx
import { useEffect, useState } from "react";

export function SamlRefresh({ orgId, staleDays = 7 }: { orgId: string; staleDays?: number }) {
  const [lastRefreshed, setLastRefreshed] = useState<Date | null>(null);
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);

  async function load() {
    setError(null);
    try {
      const r = await fetch(`/api/saml/config?org_id=${encodeURIComponent(orgId)}`);
      const cfg = await r.json();
      setLastRefreshed(cfg?.updated_at ? new Date(cfg.updated_at) : null);
      const stale = cfg?.updated_at ? (Date.now() - new Date(cfg.updated_at).getTime()) > staleDays * 24 * 3600 * 1000 : true;
      if (stale) await doRefresh();
    } catch (e: any) {
      setError(e?.message || String(e));
    }
  }

  async function doRefresh() {
    setBusy(true);
    setError(null);
    try {
      await fetch(`/saml/${encodeURIComponent(orgId)}/refresh-idp`);
      // reload new timestamp
      const r = await fetch(`/api/saml/config?org_id=${encodeURIComponent(orgId)}`);
      const cfg = await r.json();
      setLastRefreshed(cfg?.updated_at ? new Date(cfg.updated_at) : new Date());
    } catch (e: any) {
      setError(e?.message || String(e));
    } finally {
      setBusy(false);
    }
  }

  useEffect(() => { load(); /* eslint-disable-next-line react-hooks/exhaustive-deps */ }, [orgId]);

  return (
    <div>
      <button onClick={doRefresh} disabled={busy}>{busy ? "Refreshing..." : "Refresh IdP Metadata"}</button>
      <span style={{ marginLeft: 8 }}>Last refreshed: {lastRefreshed ? lastRefreshed.toLocaleString() : "—"}</span>
      {error && <span style={{ marginLeft: 8, color: 'tomato' }}>Error: {error}</span>}
    </div>
  );
}

export default SamlRefresh;
