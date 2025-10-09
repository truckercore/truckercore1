// apps/web/src/pages/status.tsx
import useSWR from 'swr'

export default function StatusPage() {
  const { data } = useSWR('/api/status/incidents', (u) => fetch(u).then(r => r.json()))
  const incidents = (data?.incidents ?? []) as any[]
  return (
    <main style={{ maxWidth: 800, margin: '32px auto', padding: 16 }}>
      <h1>Status</h1>
      <section>
        {incidents.map((i: any) => (
          <article key={i.id} style={{ border: '1px solid #e5e7eb', borderRadius: 8, padding: 12, marginBottom: 12 }}>
            <h3 style={{ margin: 0 }}>{i.title}</h3>
            <p style={{ margin: '6px 0' }}>{i.status} • Impact: {i.impact}</p>
            <p style={{ margin: '6px 0' }}>Started: {new Date(i.started_at).toLocaleString()}</p>
            {i.resolved_at && <p style={{ margin: '6px 0' }}>Resolved: {new Date(i.resolved_at).toLocaleString()}</p>}
          </article>
        ))}
        {incidents.length === 0 && (
          <p>No recent incidents.</p>
        )}
      </section>
    </main>
  )
}
