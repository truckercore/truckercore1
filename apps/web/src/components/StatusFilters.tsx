// apps/web/src/components/StatusFilters.tsx
import { useState, useEffect } from "react";

type Incident = { id: string; title: string; status?: string; impact?: string; started_at?: string; link?: string };

export function StatusFilters() {
  const [component, setComponent] = useState<string>("all");
  const [incidents, setIncidents] = useState<Incident[]>([]);

  useEffect(() => {
    const url = component === "all" ? "/api/status/incidents" : `/api/status/incidents?component=${encodeURIComponent(component)}`;
    fetch(url).then(r => r.json()).then((j) => {
      const rows: Incident[] = (j?.incidents ?? j ?? []).map((x: any) => ({
        id: String(x.id),
        title: String(x.title),
        status: x.status,
        impact: x.impact,
        started_at: x.started_at,
        link: x.link,
      }));
      setIncidents(rows);
    }).catch(() => setIncidents([]));
  }, [component]);

  return (
    <div>
      <div style={{ display: 'flex', gap: 8, alignItems: 'center', marginBottom: 8 }}>
        <select value={component} onChange={e => setComponent(e.target.value)}>
          <option value="all">All</option>
          <option value="api">API</option>
          <option value="auth">Auth</option>
          <option value="db">Database</option>
        </select>
        <a href={`/status/rss?component=${encodeURIComponent(component)}&format=rss`} target="_blank" rel="noreferrer">RSS</a>
        <a href={`/status/rss?component=${encodeURIComponent(component)}&format=atom`} target="_blank" rel="noreferrer" style={{ marginLeft: 8 }}>Atom</a>
      </div>
      <ul>
        {incidents.map(i => (
          <li key={i.id}>
            {i.title} {i.status ? `• ${i.status}` : ''} {i.impact ? `(${i.impact})` : ''}
          </li>
        ))}
      </ul>
    </div>
  );
}

export default StatusFilters;
