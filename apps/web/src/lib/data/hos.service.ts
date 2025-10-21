import { createClient } from '@supabase/supabase-js'

export type ApiError = { status: number; code?: string; message: string; requestId?: string }
export type ServiceResult<T> = { data: T | null; error: ApiError | null; requestId: string }

function normalizeError(err: any, status?: number, requestId?: string): ApiError {
  return { status: status ?? (typeof err?.status === 'number' ? err.status : 500), code: err?.code, message: err?.message ?? 'Unexpected error', requestId }
}

function getClientOrError(requestId: string): { client?: ReturnType<typeof createClient>; error?: ApiError } {
  const url = process.env.NEXT_PUBLIC_SUPABASE_URL
  const key = process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY
  if (!url || !key) return { error: { status: 500, code: 'env_missing', message: 'Supabase env not set', requestId } }
  return { client: createClient(url, key, { global: { headers: { 'x-request-id': requestId } } }) }
}

export async function listTodaySegments(driverId: string): Promise<ServiceResult<any[]>> {
  const requestId = crypto.randomUUID()
  try {
    const { client, error } = getClientOrError(requestId)
    if (error) return { data: null, error, requestId }

    // Assume occurred today by date filter; adjust if view already scoped
    const start = new Date(); start.setHours(0,0,0,0)
    const end = new Date(); end.setHours(23,59,59,999)

    const { data, error: qErr, status } = await (client as any)!
      .from('hos_segments')
      .select('id,driver_id,start_time,end_time,kind')
      .eq('driver_id', driverId)
      .gte('start_time', start.toISOString())
      .lte('start_time', end.toISOString())
      .order('start_time')

    if (qErr) return { data: null, error: normalizeError(qErr, status, requestId), requestId }
    return { data: data ?? [], error: null, requestId }
  } catch (err: any) {
    return { data: null, error: normalizeError(err, 500, requestId), requestId }
  }
}

export async function getTodayDrivingHoursLeft(driverId: string): Promise<ServiceResult<{ hours_left: number }>> {
  const requestId = crypto.randomUUID()
  try {
    const { client, error } = getClientOrError(requestId)
    if (error) return { data: null, error, requestId }

    // Use RPC if available; fallback to 0
    const { data, error: rErr, status } = await (client as any)!
      .rpc('hos_today_driving_hours', { p_driver_id: driverId })

    if (rErr) return { data: { hours_left: 0 }, error: normalizeError(rErr, status, requestId), requestId }
    const hours_left = typeof data === 'number' ? data : (Array.isArray(data) && data[0]?.hours_left) ?? 0
    return { data: { hours_left }, error: null, requestId }
  } catch (err: any) {
    return { data: { hours_left: 0 }, error: normalizeError(err, 500, requestId), requestId }
  }
}
