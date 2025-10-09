"use client"
import { useMemo, useState } from 'react'
import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query'
import { createExpense, deleteExpense, listExpenses, summarizeExpenses, updateExpense } from '@/lib/data/ownerop.service'
import type { OwnerOpExpense } from '@/types/db'
import { downloadBlob, toCSV, printPage } from '@/lib/export'

function useDriverId() {
  // Placeholder: in real app, map to auth/session
  return 'demo-driver'
}

export function ExpensesTab() {
  const driverId = useDriverId()
  const qc = useQueryClient()
  const [filters, setFilters] = useState<{ from?: string; to?: string }>({})

  const { data, isLoading, error } = useQuery({
    queryKey: ['ownerop','expenses', driverId, filters],
    queryFn: () => listExpenses({ driverId, from: filters.from, to: filters.to }).then(r => r.data ?? []),
  })

  const createMut = useMutation({
    mutationFn: (input: Omit<OwnerOpExpense, 'id'>) => createExpense(input).then(r => r.data!),
    onMutate: async (input) => {
      await qc.cancelQueries({ queryKey: ['ownerop','expenses', driverId] })
      const prev = qc.getQueryData<OwnerOpExpense[]>(['ownerop','expenses', driverId, filters]) || []
      const optimistic: OwnerOpExpense = { ...(input as any), id: 'tmp-'+Math.random().toString(36).slice(2) }
      qc.setQueryData(['ownerop','expenses', driverId, filters], [optimistic, ...prev])
      return { prev }
    },
    onError: (_e, _input, ctx) => {
      if (ctx?.prev) qc.setQueryData(['ownerop','expenses', driverId, filters], ctx.prev)
    },
    onSettled: () => {
      qc.invalidateQueries({ queryKey: ['ownerop','expenses', driverId] })
    }
  })

  const updateMut = useMutation({
    mutationFn: ({ id, patch }: { id: string; patch: Partial<OwnerOpExpense> }) => updateExpense(id, patch).then(r => r.data!),
    onMutate: async ({ id, patch }) => {
      await qc.cancelQueries({ queryKey: ['ownerop','expenses', driverId] })
      const prev = qc.getQueryData<OwnerOpExpense[]>(['ownerop','expenses', driverId, filters]) || []
      qc.setQueryData(['ownerop','expenses', driverId, filters], prev.map(r => r.id === id ? { ...r, ...patch } as OwnerOpExpense : r))
      return { prev }
    },
    onError: (_e, _i, ctx) => { if (ctx?.prev) qc.setQueryData(['ownerop','expenses', driverId, filters], ctx.prev) },
    onSettled: () => { qc.invalidateQueries({ queryKey: ['ownerop','expenses', driverId] }) }
  })

  const deleteMut = useMutation({
    mutationFn: (id: string) => deleteExpense(id).then(() => id),
    onMutate: async (id) => {
      await qc.cancelQueries({ queryKey: ['ownerop','expenses', driverId] })
      const prev = qc.getQueryData<OwnerOpExpense[]>(['ownerop','expenses', driverId, filters]) || []
      qc.setQueryData(['ownerop','expenses', driverId, filters], prev.filter(r => r.id !== id))
      return { prev }
    },
    onError: (_e, _i, ctx) => { if (ctx?.prev) qc.setQueryData(['ownerop','expenses', driverId, filters], ctx.prev) },
    onSettled: () => { qc.invalidateQueries({ queryKey: ['ownerop','expenses', driverId] }) }
  })

  const summary = useMemo(() => summarizeExpenses(data ?? []), [data])

  function exportCSV() {
    const csv = toCSV((data ?? []).map(r => ({
      date: r.occurred_at ?? '',
      category: r.category,
      amount_usd: r.amount_usd,
      miles: r.miles ?? '',
      load_id: r.load_id ?? '',
      note: r.note ?? ''
    })), ['date','category','amount_usd','miles','load_id','note'])
    downloadBlob(csv, 'expenses.csv')
  }

  return (
    <div className="space-y-4">
      <div className="flex items-center gap-2">
        <input type="date" className="border rounded p-1" value={filters.from ?? ''} onChange={e=>setFilters(f=>({...f, from: e.target.value||undefined}))} />
        <input type="date" className="border rounded p-1" value={filters.to ?? ''} onChange={e=>setFilters(f=>({...f, to: e.target.value||undefined}))} />
        <button className="ml-auto px-3 py-1 rounded border" onClick={exportCSV}>Export CSV</button>
        <button className="px-3 py-1 rounded border" onClick={printPage}>Print / PDF</button>
      </div>

      <AddExpenseForm onAdd={(exp)=> createMut.mutate(exp)} />

      <div className="rounded border">
        {isLoading ? (
          <div className="p-4">Loading…</div>
        ) : error ? (
          <div className="p-4 text-red-600">Error loading expenses</div>
        ) : (
          <table className="w-full text-sm">
            <thead>
              <tr className="bg-gray-50 text-left">
                <th className="p-2">Date</th>
                <th className="p-2">Category</th>
                <th className="p-2 text-right">Amount</th>
                <th className="p-2 text-right">Miles</th>
                <th className="p-2">Load</th>
                <th className="p-2">Note</th>
                <th className="p-2"></th>
              </tr>
            </thead>
            <tbody>
              {(data ?? []).map(r => (
                <tr key={r.id} className="border-t">
                  <td className="p-2">{r.occurred_at ? new Date(r.occurred_at).toLocaleDateString() : ''}</td>
                  <td className="p-2">{r.category}</td>
                  <td className="p-2 text-right">${'{'}r.amount_usd.toFixed(2){'}'}</td>
                  <td className="p-2 text-right">{r.miles ?? ''}</td>
                  <td className="p-2">{r.load_id ?? ''}</td>
                  <td className="p-2">{r.note ?? ''}</td>
                  <td className="p-2 text-right">
                    <button className="text-red-600 text-xs" onClick={()=> deleteMut.mutate(r.id)}>Delete</button>
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        )}
      </div>

      <div className="rounded border p-3 bg-white">
        <div className="font-medium mb-1">Totals</div>
        <div className="text-sm text-gray-700">Total: ${'{'}summary.total.toFixed(2){'}'} · Miles: {summary.miles} · Cost/Mile: ${'{'}summary.costPerMile.toFixed(2){'}'}</div>
      </div>
    </div>
  )
}

function AddExpenseForm({ onAdd }: { onAdd: (exp: Omit<OwnerOpExpense, 'id'>) => void }) {
  const driverId = useDriverId()
  const [form, setForm] = useState<Omit<OwnerOpExpense, 'id'>>({
    driver_id: driverId,
    category: 'fuel',
    amount_usd: 0,
    miles: null,
    load_id: null,
    occurred_at: new Date().toISOString().slice(0,10),
    note: ''
  })
  return (
    <form className="flex flex-wrap items-end gap-2 bg-white rounded border p-3" onSubmit={e=>{ e.preventDefault(); onAdd(form) }}>
      <label className="text-sm">Date
        <input type="date" className="block border rounded p-1" value={form.occurred_at?.slice(0,10) ?? ''} onChange={e=> setForm(f=>({...f, occurred_at: e.target.value}))} />
      </label>
      <label className="text-sm">Category
        <select className="block border rounded p-1" value={form.category} onChange={e=> setForm(f=>({...f, category: e.target.value as any}))}>
          <option value="fuel">Fuel</option>
          <option value="toll">Tolls</option>
          <option value="repair">Repairs</option>
          <option value="insurance">Insurance</option>
          <option value="other">Other</option>
        </select>
      </label>
      <label className="text-sm">Amount (USD)
        <input type="number" step="0.01" className="block border rounded p-1" value={form.amount_usd} onChange={e=> setForm(f=>({...f, amount_usd: Number(e.target.value)}))} />
      </label>
      <label className="text-sm">Miles
        <input type="number" className="block border rounded p-1" value={form.miles ?? ''} onChange={e=> setForm(f=>({...f, miles: e.target.value? Number(e.target.value) : null}))} />
      </label>
      <label className="text-sm">Load ID
        <input type="text" className="block border rounded p-1" value={form.load_id ?? ''} onChange={e=> setForm(f=>({...f, load_id: e.target.value || null}))} />
      </label>
      <label className="text-sm grow">Note
        <input type="text" className="block border rounded p-1 w-full" value={form.note ?? ''} onChange={e=> setForm(f=>({...f, note: e.target.value}))} />
      </label>
      <button type="submit" className="px-3 py-1 rounded bg-blue-600 text-white">Add</button>
    </form>
  )
}
