// TypeScript
import React from "react";

async function postJSON(url: string, body?: any) {
  const r = await fetch(url, { method: "POST", headers: { "Content-Type": "application/json" }, body: body ? JSON.stringify(body) : undefined });
  if (!r.ok) throw new Error(`${r.status} ${await r.text()}`);
  return r.json().catch(() => ({}));
}

export default function OpsAdmin() {
  const [q, setQ] = React.useState("");
  const [list, setList] = React.useState<any[]>([]);
  const [err, setErr] = React.useState<string | null>(null);

  async function searchCOI() {
    setErr(null);
    try {
      const r = await fetch(`/api/admin/coi-list?q=${encodeURIComponent(q)}&limit=50`);
      if (!r.ok) throw new Error(await r.text());
      setList(await r.json());
    } catch (e: any) {
      setErr(String(e?.message || e));
    }
  }
  async function verify(id: string, ok: boolean) {
    setErr(null);
    try {
      await postJSON(`/api/admin/coi-verify`, { id, verified: ok, note: ok ? "manual verify" : "rejected" });
      await searchCOI();
    } catch (e: any) {
      setErr(String(e?.message || e));
    }
  }
  async function reconcile(orgId: string) {
    setErr(null);
    try {
      await postJSON(`/api/admin/billing-reconcile`, { org_id: orgId });
      alert("Reconcile triggered");
    } catch (e: any) {
      setErr(String(e?.message || e));
    }
  }

  return (
    <div style={{ padding: 20 }}>
      <h2>Internal Ops</h2>

      <section style={{ marginBottom: 24 }}>
        <h3>COI Review</h3>
        <div style={{ display: "flex", gap: 8 }}>
          <input placeholder="Search by org_id, file_key, user_id…" value={q} onChange={(e) => setQ(e.target.value)} style={{ minWidth: 380 }} />
          <button onClick={searchCOI}>Search</button>
        </div>
        {err && <pre style={{ color: "crimson" }}>{err}</pre>}
        <table style={{ marginTop: 12, width: "100%" }}>
          <thead>
            <tr>
              <th>ID</th><th>Org</th><th>User</th><th>File</th><th>Verified</th><th>Uploaded</th><th>Actions</th>
            </tr>
          </thead>
          <tbody>
            {list.map((r) => (
              <tr key={r.id}>
                <td>{r.id}</td>
                <td>{r.org_id}</td>
                <td>{r.user_id}</td>
                <td><a href={`/api/admin/coi-download?id=${encodeURIComponent(r.id)}`} target="_blank" rel="noreferrer">{r.file_key}</a></td>
                <td>{String(r.verified)}</td>
                <td>{new Date(r.uploaded_at).toLocaleString()}</td>
                <td style={{ display: "flex", gap: 8 }}>
                  <button onClick={() => verify(r.id, true)}>Verify</button>
                  <button onClick={() => verify(r.id, false)}>Reject</button>
                  <button onClick={() => reconcile(r.org_id)}>Reconcile Subs</button>
                </td>
              </tr>
            ))}
          </tbody>
        </table>
      </section>

      <section>
        <h3>Entitlements Viewer</h3>
        <p>Use COI search to fetch org_id, then “Reconcile Subs” to sync plan.</p>
      </section>
    </div>
  );
}
