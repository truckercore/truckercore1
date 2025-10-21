// apps/web/src/lib/realtime/roadside.ts
// Simple realtime helpers to subscribe to roadside requests/jobs changes for an org.
import { createClient, RealtimeChannel } from '@supabase/supabase-js'

const supabase = createClient(
  process.env.NEXT_PUBLIC_SUPABASE_URL!,
  process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY!,
)

export type RoadsideHandlers = {
  onRequest?: (payload: any) => void
  onJob?: (payload: any) => void
}

export function subscribeRoadside(orgId: string, handlers: RoadsideHandlers = {}) {
  const chanReq: RealtimeChannel = supabase
    .channel(`rs:req:${orgId}`)
    .on(
      'postgres_changes',
      { event: '*', schema: 'public', table: 'roadside_requests', filter: `org_id=eq.${orgId}` },
      payload => handlers?.onRequest?.(payload)
    )
    .subscribe()

  const chanJob: RealtimeChannel = supabase
    .channel(`rs:job:${orgId}`)
    .on(
      'postgres_changes',
      { event: '*', schema: 'public', table: 'roadside_jobs', filter: `org_id=eq.${orgId}` },
      payload => handlers?.onJob?.(payload)
    )
    .subscribe()

  return () => {
    try { supabase.removeChannel(chanReq) } catch {}
    try { supabase.removeChannel(chanJob) } catch {}
  }
}
