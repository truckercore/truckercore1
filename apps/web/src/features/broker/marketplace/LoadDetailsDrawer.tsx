"use client"
import { useState } from 'react'
import { useQuery } from '@tanstack/react-query'
import { getLanePrice, getBrokerCredit } from '@/lib/data/marketplace.service'

export type LoadRow = {
  id: string
  origin: string
  destination: string
  equipment?: string | null
  pickup_at?: string | null
  broker_id?: string | null
}

export function LoadDetailsDrawer({ open, onClose, load, onApplyOffer }: {
  open: boolean
  onClose: () => void
  load: LoadRow | null
  onApplyOffer: (amountUsd: number) => void
}) {
  if (!open || !load) return null
  return (
    <div className="fixed inset-0 z-50">
      <div className="absolute inset-0 bg-black/40" onClick={onClose} />
      <div className="absolute right-0 top-0 h-full w-full max-w-lg bg-white shadow-xl p-4 overflow-y-auto">
        <Header load={load} />
        <div className="mt-4 space-y-4">
          <BidAssist load={load} onApplyOffer={onApplyOffer} />
          {/* Existing offers, details etc. could be listed here */}
        </div>
      </div>
    </div>
  )
}

function Header({ load }: { load: LoadRow }) {
  const badge = useBrokerBadge(load.broker_id)
  return (
    <div className="flex items-start justify-between">
      <div>
        <div className="text-lg font-semibold flex items-center gap-2">
          <span>{load.origin} → {load.destination}</span>
          {badge}
        </div>
        <div className="text-sm text-gray-600">{load.equipment ?? '—'} · {load.pickup_at ? new Date(load.pickup_at).toLocaleString() : ''}</div>
      </div>
      <button className="text-gray-500 hover:text-black" aria-label="Close" onClick={(e)=>{e.preventDefault();}}>
        {/* The parent overlay handles click outside; consumer should pass onClose to overlay */}
      </button>
    </div>
  )
}

function useBrokerBadge(brokerId?: string | null) {
  const { data } = useQuery({
    queryKey: ['broker','credit','drawer', brokerId],
    queryFn: async () => brokerId ? (await getBrokerCredit({ brokerId })).data : null,
    enabled: !!brokerId,
    staleTime: 5 * 60 * 1000,
  })
  if (!brokerId) return null
  const info = data as any
  const badge = computeBadge(info)
  if (!badge) return <span className="text-xs rounded px-1 border text-gray-500">No credit info</span>
  const color = badge === 'A' ? 'bg-green-100 text-green-700 border-green-300' : badge === 'B' ? 'bg-yellow-100 text-yellow-700 border-yellow-300' : 'bg-red-100 text-red-700 border-red-300'
  const tip = info ? `D2P: ${info.d2p_days ?? '—'} · Updated: ${info.updated_at ? new Date(info.updated_at).toLocaleDateString() : '—'}` : '—'
  return <span title={tip} className={`text-xs rounded px-1 border ${color}`}>{badge}</span>
}

function computeBadge(info: { tier?: string | null; d2p_days?: number | null; bond_ok?: boolean | null; insurance_ok?: boolean | null } | null): 'A'|'B'|'C'|null {
  if (!info) return null
  const tier = (info as any).tier as string | null
  if (tier === 'A' || tier === 'B' || tier === 'C') return tier as any
  const d = (info as any).d2p_days as number | null
  const bond = (info as any).bond_ok === true
  const ins = (info as any).insurance_ok === true
  if (d == null || !bond || !ins) return 'C'
  if (d <= 20 && bond && ins) return 'A'
  if (d >= 21 && d <= 35 && bond && ins) return 'B'
  return 'C'
}

function BidAssist({ load, onApplyOffer }: { load: LoadRow, onApplyOffer: (amountUsd: number) => void }) {
  const [deadheadPct, setDeadheadPct] = useState<number>(0)
  const [servicePct, setServicePct] = useState<number>(0)
  const [suggestion, setSuggestion] = useState<null | { p50: number | null; p80: number | null; suggested: number | null; rationale: string[] }>(null)
  const [error, setError] = useState<string | null>(null)
  const [loading, setLoading] = useState(false)

  async function suggest() {
    setLoading(true)
    setError(null)
    setSuggestion(null)
    const t0 = performance.now()
    try {
      const res = await getLanePrice({ lane: { origin: load.origin, destination: load.destination }, equipment: load.equipment ?? null, date: load.pickup_at ?? null })
      if (res.error) {
        setError(`Insufficient market data${res.error.message ? ': ' + res.error.message : ''}`)
        // audit error
        try { await fetch('/api/audit/log', { method: 'POST', headers: { 'content-type': 'application/json' }, body: JSON.stringify({ action: 'bid_assist', target: load.id, status: 'error', requestId: res.requestId, details: { message: res.error.message } }) }) } catch {}
      } else {
        const p50 = res.data?.p50 ?? null
        const p80 = res.data?.p80 ?? null
        if (p50 == null && p80 == null) {
          setError('Insufficient market data for this lane')
          try { await fetch('/api/audit/log', { method: 'POST', headers: { 'content-type': 'application/json' }, body: JSON.stringify({ action: 'bid_assist', target: load.id, status: 'error', requestId: res.requestId, details: { message: 'no_data' } }) }) } catch {}
        } else {
          const base = p50 ?? p80 ?? 0
          // Simple adjustments
          const adj = base * (1 + (deadheadPct/100) + (servicePct/100))
          const rationale = [
            `Base ${p50 != null ? 'p50' : 'p80'}: $${base.toFixed(0)}`,
            deadheadPct ? `Deadhead adj: ${deadheadPct}%` : 'Deadhead adj: 0%',
            servicePct ? `Service window adj: ${servicePct}%` : 'Service window adj: 0%'
          ]
          const suggested = Math.round(adj)
          setSuggestion({ p50, p80, suggested, rationale })
          // audit ok
          try { await fetch('/api/audit/log', { method: 'POST', headers: { 'content-type': 'application/json' }, body: JSON.stringify({ action: 'bid_assist', target: load.id, status: 'ok', requestId: res.requestId, details: { p50, p80, suggested, deadheadPct, servicePct } }) }) } catch {}
        }
      }
    } finally {
      const dt = performance.now() - t0
      // could log timing
      setLoading(false)
    }
  }

  return (
    <div className="rounded border p-3">
      <div className="font-medium mb-2">Bid Assist</div>
      <div className="flex flex-wrap items-end gap-2">
        <label className="text-sm">Deadhead %
          <input type="number" className="block border rounded p-1 w-24" value={deadheadPct} onChange={e=> setDeadheadPct(Number(e.target.value||0))} />
        </label>
        <label className="text-sm">Service window %
          <input type="number" className="block border rounded p-1 w-24" value={servicePct} onChange={e=> setServicePct(Number(e.target.value||0))} />
        </label>
        <button className="ml-auto px-3 py-1 rounded bg-blue-600 text-white" onClick={suggest} disabled={loading}>{loading? 'Suggesting…' : 'Suggest Bid'}</button>
      </div>
      {error ? <div className="mt-2 text-sm text-red-600">{error}</div> : null}
      {suggestion && (
        <div className="mt-3 text-sm">
          <div className="font-semibold">Suggested: ${suggestion.suggested?.toFixed(0)}</div>
          <div className="text-gray-700">Band: ${suggestion.p50 ?? '—'} – ${suggestion.p80 ?? '—'}</div>
          <ul className="list-disc pl-5 mt-1 text-gray-700">
            {suggestion.rationale.map((r,i)=> <li key={i}>{r}</li>)}
          </ul>
          <button className="mt-2 px-3 py-1 rounded border" onClick={()=> suggestion?.suggested != null && onApplyOffer(suggestion.suggested!)}>Apply to Offer</button>
        </div>
      )}
    </div>
  )
}
