import { supabase } from '@/lib/supabase'

export type ApiError = {
  status: number
  code?: string
  message: string
  requestId?: string
}

// Lightweight latency instrumentation: logs duration and table name
function logLatency(table: string, ms: number, requestId: string) {
  try {
    // eslint-disable-next-line no-console
    console.info('[WIDGET_QUERY]', JSON.stringify({ table, ms, requestId, t: new Date().toISOString() }))
  } catch (_) { /* ignore */ }
}

export async function fetchTable<T>(
  table: string,
  builder?: (q: any) => any,
): Promise<T[]> {
  const requestId = crypto.randomUUID()
  const base = supabase.from(table)
  const query = builder ? builder(base as any) : (base.select('*') as any)
  const t0 = performance.now()
  const { data, error, status } = await query
  const t1 = performance.now()
  logLatency(table, Math.round(t1 - t0), requestId)
  if (error) throw normalizeError(error, status, requestId)
  return data as T[]
}

export function normalizeError(err: any, status?: number, requestId?: string): ApiError {
  return {
    status: status ?? (typeof err?.status === 'number' ? err.status : 500),
    code: err?.code,
    message: err?.message ?? 'Unexpected error',
    requestId,
  }
}
