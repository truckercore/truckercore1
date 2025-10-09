"use client"
import React from 'react'

export function SafetyExporter({ rows, requestId }: { rows: any[]; requestId?: string }) {
  async function audit(details: any) {
    try { await fetch('/api/audit/log', { method: 'POST', headers: { 'content-type': 'application/json' }, body: JSON.stringify({ action: 'safety_export', status: 'ok', target: null, requestId, details }) }) } catch {}
  }

  function toCSV(items: any[]): string {
    const cols = ['id','driver_id','occurred_at','event_type','raw_type','severity','severity_bucket']
    const header = cols.join(',')
    const lines = items.map(r => {
      const severity = r.severity ?? r.severity_int ?? ''
      const bucket = r.severity_bucket ?? (severity >= 4 ? 'high' : severity === 3 ? 'medium' : severity ? 'low' : '')
      const vals = [r.id, r.driver_id, r.occurred_at, r.event_type ?? '', r.raw_type ?? r.type ?? '', severity, bucket]
      return vals.map(v => typeof v === 'string' ? '"' + v.replace(/"/g,'""') + '"' : v).join(',')
    })
    return [header, ...lines].join('\n')
  }

  const onExportCSV = async () => {
    const csv = toCSV(rows)
    const blob = new Blob([csv], { type: 'text/csv' })
    const url = URL.createObjectURL(blob)
    const a = document.createElement('a')
    a.href = url
    a.download = `safety_incidents_${new Date().toISOString().slice(0,10)}.csv`
    document.body.appendChild(a)
    a.click()
    document.body.removeChild(a)
    URL.revokeObjectURL(url)
    audit({ format: 'csv', count: rows.length })
  }

  const onExportPDF = async () => {
    try {
      const gateRes = await fetch('/api/safety/export/pdf-gate')
      const gate = await gateRes.json()
      if (!gateRes.ok || !gate?.enabled) {
        alert(`PDF export disabled${gate?.error?.requestId ? ' · requestId=' + gate.error.requestId : ''}`)
        return
      }
      const printWindow = window.open('', '_blank')
      if (!printWindow) return
      const dt = new Date().toLocaleString()
      printWindow.document.write(`<!doctype html><html><head><title>Safety Export</title><link rel="stylesheet" href="/styles/print.css" /></head><body>`)
      printWindow.document.write(`<h1>Safety Incidents</h1><div>Date: ${dt}</div>`)
      printWindow.document.write(`<table style="width:100%; border-collapse:collapse" border="1"><thead><tr><th>ID</th><th>Driver</th><th>Occurred</th><th>Type</th><th>Severity</th></tr></thead><tbody>`)
      rows.forEach(r => {
        const sev = r.severity ?? r.severity_int ?? ''
        const t = r.raw_type ?? r.type ?? ''
        printWindow!.document.write(`<tr><td>${r.id}</td><td>${r.driver_id}</td><td>${r.occurred_at ?? ''}</td><td>${t}</td><td>${sev}</td></tr>`)
      })
      printWindow.document.write(`</tbody></table><footer style="position:fixed;bottom:8px;left:8px;right:8px;text-align:center;opacity:0.6;font-size:12px">Confidential – TruckerCore</footer></body></html>`)
      printWindow.document.close()
      printWindow.focus()
      printWindow.print()
      audit({ format: 'pdf', count: rows.length })
    } catch (e:any) {
      alert(`PDF export failed${e?.message ? ': ' + e.message : ''}`)
    }
  }

  return (
    <div className="flex items-center gap-2">
      <button className="text-xs px-2 py-1 rounded border" onClick={onExportCSV}>Export CSV</button>
      <button className="text-xs px-2 py-1 rounded border" onClick={onExportPDF}>Export PDF</button>
    </div>
  )
}
