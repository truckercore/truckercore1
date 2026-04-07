"use client"
import React from 'react'
import { useQuery } from '@tanstack/react-query'
import { createClient } from '@supabase/supabase-js'

function useSupabase() {
  const url = process.env.NEXT_PUBLIC_SUPABASE_URL as string | undefined
  const key = process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY as string | undefined
  return React.useMemo(()=> (url && key) ? createClient(url, key) : null, [url, key])
}

export function SafetyAnalytics() {
  const sb = useSupabase()
  const byType = useQuery({
    queryKey: ['analytics','safety','30d'],
    queryFn: async () => {
      if (!sb) return []
      const { data } = await (sb as any).from('mv_safety_incidents_30d').select('*')
      return data ?? []
    }
  })
  const trend = useQuery({
    queryKey: ['analytics','safety','90d'],
    queryFn: async () => {
      if (!sb) return []
      const { data } = await (sb as any).from('mv_safety_incidents_90d_trend').select('*')
      return data ?? []
    }
  })

  return (
    <div className="rounded border bg-white p-3">
      <div className="font-medium mb-2">Analytics</div>
      <div className="grid grid-cols-1 md:grid-cols-2 gap-3">
        <div className="rounded border p-2">
          <div className="font-medium mb-1">Incidents by Type (30d)</div>
          {!byType.data?.length ? <div className="text-sm text-gray-600">No data</div> : (
            <ul className="text-sm space-y-1">
              {byType.data.map((r:any)=> (
                <li key={r.type} className="flex justify-between"><span className="capitalize">{(r.type||'').replace('_',' ')}</span><span>{r.count}</span></li>
              ))}
            </ul>
          )}
        </div>
        <div className="rounded border p-2">
          <div className="font-medium mb-1">Daily incidents (90d)</div>
          {!trend.data?.length ? <div className="text-sm text-gray-600">No data</div> : (
            <ul className="text-sm space-y-1 max-h-48 overflow-auto">
              {trend.data.map((r:any)=> (
                <li key={r.day} className="flex justify-between"><span>{r.day}</span><span>{r.count}</span></li>
              ))}
            </ul>
          )}
        </div>
      </div>
    </div>
  )
}
