"use client"
import { useQuery } from '@tanstack/react-query'
import { listExpenses, summarizeExpenses } from '@/lib/data/ownerop.service'

function useDriverId() { return 'demo-driver' }

export function ProfitabilityTab() {
  const driverId = useDriverId()
  const { data } = useQuery({
    queryKey: ['ownerop','expenses', driverId],
    queryFn: () => listExpenses({ driverId }).then(r => r.data ?? [])
  })

  const summary = summarizeExpenses(data ?? [])

  // Placeholder revenue; in real setup, join loads for actual revenue
  const grossRevenue = null as number | null
  const netProfit = grossRevenue != null ? (grossRevenue - summary.total) : null
  const ppm = summary.miles > 0 && grossRevenue != null ? grossRevenue / summary.miles : null

  return (
    <div className="grid grid-cols-1 md:grid-cols-3 gap-3">
      <Card title="Gross Revenue" value={grossRevenue != null ? `$${grossRevenue.toFixed(2)}` : '—'} />
      <Card title="Total Costs" value={`$${summary.total.toFixed(2)}`} />
      <Card title="Net Profit" value={netProfit != null ? `$${netProfit.toFixed(2)}` : '—'} />
      <Card title="Miles" value={String(summary.miles)} />
      <Card title="Cost / Mile" value={`$${summary.costPerMile.toFixed(2)}`} />
      <Card title="PPM (Revenue/Mile)" value={ppm != null ? `$${ppm.toFixed(2)}` : '—'} />
    </div>
  )
}

function Card({ title, value }: { title: string; value: string }) {
  return (
    <div className="rounded border bg-white p-3">
      <div className="text-xs text-gray-600">{title}</div>
      <div className="text-lg font-semibold">{value}</div>
    </div>
  )
}
