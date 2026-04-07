"use client"
import { useQuery } from '@tanstack/react-query'
import { downloadBlob, toCSV, printPage } from '@/lib/export'
import { getTodayDrivingHoursLeft, listTodaySegments } from '@/lib/data/hos.service'

function useDriverId() { return 'demo-driver' }

type Segment = { id: string; start_time: string; end_time?: string | null; kind: string }

export function HOSTab() {
  const driverId = useDriverId()
  const segQ = useQuery({ queryKey: ['hos','segments', driverId], queryFn: () => listTodaySegments(driverId).then(r => r.data ?? []) })
  const leftQ = useQuery({ queryKey: ['hos','left', driverId], queryFn: () => getTodayDrivingHoursLeft(driverId).then(r => r.data ?? { hours_left: 0 }) })

  function exportCSV() {
    const rows = (segQ.data ?? []).map((s: Segment) => ({
      start_time: s.start_time,
      end_time: s.end_time ?? '',
      kind: s.kind
    }))
    const csv = toCSV(rows, ['start_time','end_time','kind'])
    downloadBlob(csv, 'hos_today.csv')
  }

  return (
    <div className="space-y-3">
      <div className="flex items-center gap-2">
        <button className="ml-auto px-3 py-1 rounded border" onClick={exportCSV}>Export CSV</button>
        <button className="px-3 py-1 rounded border" onClick={printPage}>Print / PDF</button>
      </div>

      <div className="rounded border bg-white p-3">
        <div className="font-medium mb-2">Today HOS Grid</div>
        {segQ.isLoading ? <div>Loading…</div> : (
          <Grid segments={(segQ.data ?? []) as Segment[]} />
        )}
      </div>

      <div className="rounded border bg-white p-3">
        <div className="font-medium mb-2">Driving Hours Left Today</div>
        <div className="text-lg font-semibold">{leftQ.data?.hours_left ?? 0} h</div>
      </div>
    </div>
  )
}

function Grid({ segments }: { segments: Segment[] }) {
  // Simple text-based grid; placeholder for a proper duty chart
  return (
    <ul className="text-sm space-y-1">
      {segments.map(s => (
        <li key={s.id} className="flex justify-between">
          <span className="text-gray-600">{new Date(s.start_time).toLocaleTimeString()} – {s.end_time ? new Date(s.end_time).toLocaleTimeString() : 'now'}</span>
          <span className="font-medium">{s.kind}</span>
        </li>
      ))}
    </ul>
  )
}
