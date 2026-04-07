"use client"
import React from 'react'
import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query'
import { createCoachingTask, listSafetyIncidents, listSafetyScores, addAcknowledgementNote, resolveIncident } from '@/lib/data/fleet.service'
import { useFeatureFlags } from '@/lib/featureFlags'
import { SafetyExporter } from '@/features/fleet/safety/exports/Exporter'

export function SafetyLite() {
  const [typeFilter, setTypeFilter] = React.useState<string[]>([])
  const incidents = useQuery({ queryKey: ['fleet','safety','incidents'], queryFn: () => listSafetyIncidents().then(r => r.data ?? []) })
  const scores = useQuery({ queryKey: ['fleet','safety','scores'], queryFn: () => listSafetyScores().then(r => r.data ?? []) })
  const qc = useQueryClient()
  const coaching = useMutation({
    mutationFn: (input: { driver_id: string; note: string; incident_id?: string | null; assignee_id?: string | null; due_date?: string | null }) => createCoachingTask(input).then(r => {
      if (!r.data) throw Object.assign(new Error(r.error?.message ?? 'Failed'), { requestId: r.requestId })
      return r.data
    }),
    onSuccess: () => { qc.invalidateQueries({ queryKey: ['fleet','safety','incidents'] }) },
    onError: (e:any) => { alert(`Coaching failed${e?.message ? ': ' + e.message : ''}${e?.requestId ? ' · requestId=' + e.requestId : ''}`) }
  })

  const options = [
    'accident','inspection','violation','near_miss','speeding','seatbelt','distracted','harsh_brake','harsh_accel','cornering','other'
  ]

  const rows = (incidents.data ?? []) as any[]
  const filtered = typeFilter.length ? rows.filter(r => {
    const raw = (r.raw_type ?? r.type ?? '').toString()
    return typeFilter.includes(raw)
  }) : rows

  return (
    <div className="grid grid-cols-1 md:grid-cols-3 gap-3">
      <div className="rounded border bg-white p-3 md:col-span-2">
        <div className="flex items-center justify-between mb-2">
          <div className="font-medium">Safety Inbox</div>
          <div className="flex items-center gap-2 text-sm">
            <SafetyExporter rows={filtered} />
            <label className="text-gray-700">Type</label>
            <select multiple className="border rounded p-1 min-w-[220px]" value={typeFilter} onChange={(e)=>{
              const vals = Array.from(e.target.selectedOptions).map(o=> o.value)
              setTypeFilter(vals)
            }}>
              {options.map(opt => <option key={opt} value={opt}>{opt}</option>)}
            </select>
            {typeFilter.length > 0 && (
              <button className="text-xs text-gray-600 underline" onClick={()=> setTypeFilter([])}>Clear</button>
            )}
          </div>
        </div>
        {incidents.isLoading ? <div>Loading…</div> : (
          <ul className="divide-y">
            {filtered.map((i:any)=> (
              <li key={i.id} className="py-2 text-sm flex items-start justify-between">
                <div>
                  <div className="flex items-center gap-2 font-medium">
                    <span className="inline-flex items-center gap-1">
                      <TypeChip value={(i.raw_type ?? i.type) as any} />
                    </span>
                    <SeverityBadge value={i.severity} />
                    {i.resolved ? <span className="text-xs px-2 py-0.5 rounded border bg-green-50 text-green-700">Resolved</span> : null}
                  </div>
                  <div className="text-gray-600">Driver: {i.driver_id} · {i.occurred_at ? new Date(i.occurred_at).toLocaleString() : ''}</div>
                  <div className="mt-1 flex gap-2">
                    <AssignInline incident={i} onAssign={(payload)=> coaching.mutate(payload)} />
                    <AckToggle incident={i} />
                    {!i.resolved && <ResolveButton incident={i} />}
                  </div>
                </div>
              </li>
            ))}
          </ul>
        )}
      </div>

      <div className="rounded border bg-white p-3">
        <div className="flex items-center justify-between mb-2">
          <div className="font-medium">Rolling Driver Score</div>
          <RecomputeScoresButton />
        </div>
        {scores.isLoading ? <div>Loading…</div> : (
          <ul className="space-y-1 text-sm">
            {(scores.data ?? []).slice(0,10).map((s:any)=> (
              <li key={s.driver_id} className="flex justify-between"><span>{s.driver_id}</span><span className="font-semibold">{s.score}</span></li>
            ))}
          </ul>
        )}
      </div>
    </div>
  )
}

function AssignInline({ incident, onAssign }: { incident: any; onAssign: (payload: { driver_id: string; note: string; incident_id?: string | null; assignee_id?: string | null; due_date?: string | null }) => void }) {
  const [assignee, setAssignee] = React.useState<string>('')
  const [due, setDue] = React.useState<string>('')
  const [note, setNote] = React.useState<string>('')
  return (
    <div className="flex items-end gap-2">
      <input className="border rounded p-1 text-xs" placeholder="Assignee" value={assignee} onChange={e=> setAssignee(e.target.value)} />
      <input className="border rounded p-1 text-xs" type="date" value={due} onChange={e=> setDue(e.target.value)} />
      <input className="border rounded p-1 text-xs min-w-[160px]" placeholder="Note" value={note} onChange={e=> setNote(e.target.value)} />
      <button className="text-xs px-2 py-1 rounded border" onClick={()=> onAssign({ driver_id: incident.driver_id, note: note || `Coaching for incident ${incident.id}`, incident_id: incident.id, assignee_id: assignee || undefined, due_date: due || undefined })}>Assign</button>
    </div>
  )
}

function AckToggle({ incident }: { incident: any }) {
  const qc = useQueryClient()
  const mut = useMutation({
    mutationFn: async () => {
      const res = await addAcknowledgementNote(incident.id)
      if (res.error) throw Object.assign(new Error(res.error.message), { requestId: res.requestId })
      return res.data
    },
    onMutate: async () => {
      await qc.cancelQueries({ queryKey: ['fleet','safety','incidents'] })
      const prev = qc.getQueryData<any[]>(['fleet','safety','incidents'])
      // optimistic: mark acknowledged flag
      qc.setQueryData<any[]>(['fleet','safety','incidents'], (old)=> (old ?? []).map(r=> r.id === incident.id ? { ...r, acknowledged: true } : r))
      return { prev }
    },
    onError: (e:any, _vars, ctx:any) => {
      if (ctx?.prev) qc.setQueryData(['fleet','safety','incidents'], ctx.prev)
      alert(`Acknowledge failed${e?.message ? ': ' + e.message : ''}${e?.requestId ? ' · requestId=' + e.requestId : ''}`)
    },
    onSettled: () => { qc.invalidateQueries({ queryKey: ['fleet','safety','incidents'] }) }
  })
  return <button className="text-xs text-gray-700 underline" onClick={()=> mut.mutate()}>Driver acknowledged</button>
}

function ResolveButton({ incident }: { incident: any }) {
  const qc = useQueryClient()
  const mut = useMutation({
    mutationFn: async () => {
      const res = await resolveIncident(incident.id)
      if (res.error) throw Object.assign(new Error(res.error.message), { requestId: res.requestId })
      return res.data
    },
    onMutate: async () => {
      await qc.cancelQueries({ queryKey: ['fleet','safety','incidents'] })
      const prev = qc.getQueryData<any[]>(['fleet','safety','incidents'])
      qc.setQueryData<any[]>(['fleet','safety','incidents'], (old)=> (old ?? []).map(r=> r.id === incident.id ? { ...r, resolved: true, resolved_at: new Date().toISOString() } : r))
      return { prev }
    },
    onError: (e:any, _vars, ctx:any) => {
      if (ctx?.prev) qc.setQueryData(['fleet','safety','incidents'], ctx.prev)
      alert(`Resolve failed${e?.message ? ': ' + e.message : ''}${e?.requestId ? ' · requestId=' + e.requestId : ''}`)
    },
    onSettled: () => { qc.invalidateQueries({ queryKey: ['fleet','safety','incidents'] }) }
  })
  return <button className="text-xs text-green-700 underline" onClick={()=> mut.mutate()}>Resolve</button>
}

function RecomputeScoresButton() {
  const flags = useFeatureFlags()
  const qc = useQueryClient()
  const [loading, setLoading] = React.useState(false)
  if (!flags?.admin_safety_tools) return null
  const onClick = async () => {
    setLoading(true)
    try {
      const res = await fetch('/api/safety/score-refresh', { method: 'POST' })
      const json = await res.json()
      if (!res.ok) throw Object.assign(new Error(json?.error?.message ?? 'Failed'), { requestId: json?.error?.requestId })
      // refetch scores after success
      qc.invalidateQueries({ queryKey: ['fleet','safety','scores'] })
    } catch (e:any) {
      alert(`Refresh failed${e?.message ? ': ' + e.message : ''}${e?.requestId ? ' · requestId=' + e.requestId : ''}`)
    } finally {
      setLoading(false)
    }
  }
  return <button className="text-xs px-2 py-1 rounded border" onClick={onClick} disabled={loading}>{loading ? 'Recomputing…' : 'Recompute scores'}</button>
}

function TypeChip({ value }: { value?: string | null }) {
  const v = (value ?? 'other').toString()
  return <span className="text-xs px-2 py-0.5 rounded-full border bg-gray-50 capitalize">{v.replace('_',' ')}</span>
}

export function severityBucket(n?: number) {
  if (!n || Number.isNaN(n)) return 'none'
  if (n >= 4) return 'high'
  if (n === 3) return 'medium'
  return 'low'
}

function SeverityBadge({ value }: { value?: number | string | null }) {
  const n = typeof value === 'number' ? value : (value ? parseInt(String(value), 10) : undefined)
  const bucket = severityBucket(n as any)
  const color = bucket === 'none' ? 'bg-gray-100 text-gray-700 border-gray-300' : bucket === 'high' ? 'bg-red-100 text-red-700 border-red-300' : bucket === 'medium' ? 'bg-yellow-100 text-yellow-700 border-yellow-300' : 'bg-green-100 text-green-700 border-green-300'
  return <span className={`text-xs px-2 py-0.5 rounded border ${color}`}>Severity {n ?? '—'}</span>
}
