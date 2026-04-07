"use client"
import { useState } from 'react'
import { useMutation, useQuery } from '@tanstack/react-query'
import { listOpenLoads, getBrokerCredit as getBrokerCreditSvc, createOffer } from '@/lib/data/marketplace.service'
import { LoadDetailsDrawer, type LoadRow } from '@/features/broker/marketplace/LoadDetailsDrawer'

function useCarrierId() { return 'demo-carrier' }

export function OpenLoadsList() {
  const { data, error, isLoading } = useQuery({
    queryKey: ['marketplace','openLoads'],
    queryFn: () => listOpenLoads().then(r => ({...r, rows: r.data?.rows ?? []})),
  })
  const [open, setOpen] = useState(false)
  const [selected, setSelected] = useState<LoadRow | null>(null)
  const carrierId = useCarrierId()

  const offerMut = useMutation({
    mutationFn: async ({ amount }: { amount: number }) => {
      if (!selected) throw new Error('No load selected')
      const res = await createOffer({ loadId: selected.id, carrierId, bidUsd: amount })
      if (res.error || !res.data) throw Object.assign(new Error(res.error?.message ?? 'Offer failed'), { requestId: res.requestId })
      return res.data
    },
    onSuccess: (_data) => {
      alert('Offer submitted successfully')
    },
    onError: (e: any) => {
      alert(`Offer failed${e?.message ? ': ' + e.message : ''}${e?.requestId ? ' · requestId=' + e.requestId : ''}`)
    }
  })

  if (isLoading) return <div className="p-4">Loading loads…</div>
  if (error) return <div className="p-4 text-red-600">Error loading: {(error as any).message}</div>
  const rows = (data as any)?.rows ?? []
  if (!rows.length) return <div className="p-4 text-gray-600">No open loads</div>

  function onRowClick(l: any) {
    const load: LoadRow = { id: l.id, origin: l.origin, destination: l.destination, equipment: l.equipment ?? null, pickup_at: l.pickup_at ?? null, broker_id: l.broker_id ?? null }
    setSelected(load)
    setOpen(true)
  }

  return (
    <>
      <ul className="divide-y rounded border bg-white">
        {rows.map((l:any)=> (
          <li key={l.id} className="p-3 flex items-center justify-between hover:bg-gray-50 cursor-pointer" onClick={()=> onRowClick(l)}>
            <div>
              <div className="font-medium flex items-center gap-2">
                <span>{l.origin} → {l.destination}</span>
                <BrokerBadge brokerId={l.broker_id} />
              </div>
              <div className="text-sm text-gray-500">{l.equipment ?? '—'}</div>
            </div>
            <div className="text-sm">{l.pickup_at ? new Date(l.pickup_at).toLocaleString() : ''}</div>
          </li>
        ))}
      </ul>

      <LoadDetailsDrawer
        open={open}
        onClose={()=> setOpen(false)}
        load={selected}
        onApplyOffer={(amount)=> offerMut.mutate({ amount })}
      />
    </>
  )
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

function BrokerBadge({ brokerId }: { brokerId?: string | null }) {
  const { data } = useQuery({
    queryKey: ['broker','credit', brokerId],
    queryFn: async () => brokerId ? (await getBrokerCreditSvc({ brokerId })).data : null,
    enabled: !!brokerId,
    staleTime: 5 * 60 * 1000,
  })
  if (!brokerId) return null
  const info = data as any
  const badge = computeBadge(info)
  if (!badge) return <span className="text-xs rounded px-1 border text-gray-500">No credit info</span>
  const color = badge === 'A' ? 'bg-green-100 text-green-700 border-green-300' : badge === 'B' ? 'bg-yellow-100 text-yellow-700 border-yellow-300' : 'bg-red-100 text-red-700 border-red-300'
  const tip = info ? `D2P: ${info.d2p_days ?? '—'} · Updated: ${info.updated_at ? new Date(info.updated_at).toLocaleDateString() : '—'}` : '—'
  return (
    <span title={tip} className={`text-xs rounded px-1 border ${color}`}>{badge}</span>
  )
}
