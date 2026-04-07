import { useEffect, useMemo, useState } from 'react'
import { createClient } from '@supabase/supabase-js'

type AlertType = 'SLOWDOWN'|'WORKZONE'|'WEATHER'|'SPEED'|'OFFROUTE'|'WEIGH'|'FATIGUE'
type Alert = {
  id: string
  alert_type: AlertType
  message?: string | null
  fired_at: string
  road_name?: string | null
}

const supabase = createClient(
  process.env.NEXT_PUBLIC_SUPABASE_URL!,
  process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY!
)

const TABS: { key: 'ALL'|AlertType; label: string }[] = [
  { key: 'ALL', label: 'All' },
  { key: 'SLOWDOWN', label: 'Slowdowns' },
  { key: 'WORKZONE', label: 'Work Zones' },
  { key: 'WEATHER', label: 'Weather' },
  { key: 'SPEED', label: 'Speed' },
  { key: 'OFFROUTE', label: 'Off	Route' },
  { key: 'WEIGH', label: 'Weigh' },
  { key: 'FATIGUE', label: 'Fatigue' },
]

export default function SlowdownFeed() {
  const [active, setActive] = useState<'ALL'|AlertType>('ALL')
  const [alerts, setAlerts] = useState<Alert[]>([])
  const [coachTip, setCoachTip] = useState<string>('')

  const typesForQuery = useMemo<AlertType[] | undefined>(() => {
    if (active === 'ALL') return undefined
    return [active]
  }, [active])

  useEffect(() => {
    let cancelled = false
    const load = async () => {
      const base = supabase.from('safety_alerts').select('id, alert_type, fired_at, road_name, message')
      const q = typesForQuery
        ? base.in('alert_type', typesForQuery as AlertType[])
        : base.in('alert_type', ['SLOWDOWN','WORKZONE','WEATHER','SPEED','OFFROUTE','WEIGH','FATIGUE'])
      const { data, error } = await q.order('fired_at', { ascending: false }).limit(100)
      if (!cancelled && !error) setAlerts((data as Alert[]) ?? [])
    }
    load()
    const ch = supabase
      .channel('safety_alerts_feed')
      .on('postgres_changes', { event: 'INSERT', schema: 'public', table: 'safety_alerts' }, (p: any) => {
        const row = p.new as Alert
        if (active === 'ALL' || row.alert_type === active) {
          setAlerts(prev => [row, ...prev].slice(0, 100))
        }
      })
      .subscribe()
    // Also pick up last coach tip (written by Edge Function)
    const loadCoach = async () => {
      const { data } = await supabase
        .from('coach_tips')
        .select('tip')
        .order('created_at', { ascending: false })
        .limit(1)
        .maybeSingle()
      if (!cancelled && (data as any)?.tip) setCoachTip((data as any).tip as string)
    }
    loadCoach()
    return () => {
      cancelled = true
      supabase.removeChannel(ch)
    }
  }, [active, typesForQuery])

  return (
    <div className="space-y-3">
      <div className="flex flex-wrap gap-2">
        {TABS.map(t => (
          <button
            key={t.key}
            onClick={() => setActive(t.key)}
            className={`px-3 py-1 rounded text-sm ${
              active === t.key ? 'bg-blue-600 text-white' : 'bg-gray-800 text-gray-200'
            }`}
          >
            {t.label}
          </button>
        ))}
      </div>
      {coachTip ? (
        <div className="rounded-md border border-purple-500/40 bg-purple-500/10 p-3 text-sm text-purple-200">
          RoadDogg Tip: {coachTip}
        </div>
      ) : null}
      <ul className="divide-y divide-gray-800 rounded-md border border-gray-800">
        {alerts.map(a => (
          <li key={a.id} className="p-3">
            <div className="flex items-center justify-between">
              <div className="text-sm font-medium">{a.alert_type}</div>
              <div className="text-xs text-gray-400">{new Date(a.fired_at).toLocaleString()}</div>
            </div>
            <div className="text-sm text-gray-200">{a.message || a.road_name || '—'}</div>
          </li>
        ))}
        {alerts.length === 0 && (
          <li className="p-6 text-center text-sm text-gray-400">No alerts</li>
        )}
      </ul>
    </div>
  )
}
