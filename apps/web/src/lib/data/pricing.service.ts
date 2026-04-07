import { createClient } from '@supabase/supabase-js'
import type { MarketRateDaily, BrokerCredit } from '@/types/db'
import type { ApiError } from './fetcher'

export type ServiceResult<T> = { data: T | null, error: ApiError | null, requestId: string }

export async function getLaneRates(
  params: { origin: string; destination: string; equipment?: string; date?: string }
): Promise<ServiceResult<Pick<MarketRateDaily, 'p50' | 'p80'> | null>> {
  const requestId = crypto.randomUUID()
  try {
    const url = process.env.NEXT_PUBLIC_SUPABASE_URL
        const key = process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY
        if (!url || !key) {
          return { data: null, error: { status: 500, code: 'env_missing', message: 'Supabase env not set', requestId }, requestId }
        }
        const supabase = createClient(url, key)
        let q = supabase.from('market_rates_daily')
      .select('p50,p80')
      .eq('origin', params.origin)
      .eq('destination', params.destination)
      .limit(1)

    if (params.equipment) q = q.eq('equipment', params.equipment)
    if (params.date) q = q.eq('service_date', params.date)

    const { data, error, status } = await q.maybeSingle()
    if (error) {
      return { data: null, error: normalizeError(error, status, requestId), requestId }
    }
    return { data: data ?? null, error: null, requestId }
  } catch (err: any) {
    return { data: null, error: normalizeError(err, 500, requestId), requestId }
  }
}

export async function getBrokerCredit(brokerId: string): Promise<ServiceResult<BrokerCredit | null>> {
  const requestId = crypto.randomUUID()
  try {
    const url = process.env.NEXT_PUBLIC_SUPABASE_URL
    const key = process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY
    if (!url || !key) {
      return { data: null, error: { status: 500, code: 'env_missing', message: 'Supabase env not set', requestId }, requestId }
    }
    const supabase = createClient(url, key)
    const { data, error, status } = await supabase
      .from('broker_credit')
      .select('broker_id,tier,d2p_days,bond_ok,insurance_ok,updated_at')
      .eq('broker_id', brokerId)
      .maybeSingle()

    if (error) return { data: null, error: normalizeError(error, status, requestId), requestId }
    return { data: data ?? null, error: null, requestId }
  } catch (err: any) {
    return { data: null, error: normalizeError(err, 500, requestId), requestId }
  }
}

function normalizeError(err: any, status?: number, requestId?: string): ApiError {
  return {
    status: status ?? (typeof err?.status === 'number' ? err.status : 500),
    code: err?.code,
    message: err?.message ?? 'Unexpected error',
    requestId,
  }
}
