import React, { useEffect, useState } from 'react'
import { createClient } from '@supabase/supabase-js'

type Row = {
  id: string
  alert_type?: string
  message?: string
  fired_at: string
  road_name?: string
  eta_delta_sec?: number
  ahead_distance_m?: number
}

const supabase = createClient(
  process.env.NEXT_PUBLIC_SUPABASE_URL!,
  process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY!
)

export default function SlowdownFeed() {
  const [rows, setRows] = useState<Row[]>([])

  useEffect(() => {
    supabase
      .from('safety_alerts')
      .select('*')
      .order('fired_at', { ascending: false })
      .limit(50)
      .then(({ data }) => setRows((data as Row[]) || []))

    const ch = supabase
      .channel('safety_alerts')
      .on(
        'postgres_changes',
        { event: 'INSERT', schema: 'public', table: 'safety_alerts' },
        (p) => setRows((r) => [p.new as Row, ...r].slice(0, 100))
      )
      .subscribe()

    return () => {
      try {
        ch.unsubscribe()
      } catch {}
    }
  }, [])

  return (
    <div className="space-y-2">
      {rows.map((r) => (
        <div key={r.id} className="rounded-xl border p-3">
          <div className="text-sm font-semibold">
            {r.alert_type} · {r.road_name || 'Road'}
          </div>
          <div className="text-xs opacity-80">
            {new Date(r.fired_at).toLocaleString()} · ETA +{Math.round(((r.eta_delta_sec || 0) / 60))} min · Ahead {r.ahead_distance_m} m
          </div>
          <div className="text-sm">{r.message}</div>
        </div>
      ))}
    </div>
  )
}
