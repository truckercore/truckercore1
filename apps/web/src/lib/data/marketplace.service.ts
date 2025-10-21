import { createClient } from '@supabase/supabase-js'
import type { BrokerCredit, MarketRateDaily, MarketplaceLoad, MarketplaceOffer, QuoteEvent } from '@/types/db'

export type ApiError = { status: number; code?: string; message: string; requestId?: string }
export type ServiceResult<T> = { data: T | null; error: ApiError | null; requestId: string }

function normalizeError(err: any, status?: number, requestId?: string): ApiError {
  return {
    status: status ?? (typeof err?.status === 'number' ? err.status : 500),
    code: err?.code ?? 'unknown',
    message: err?.message ?? 'Unexpected error',
    requestId,
  }
}

function getClientOrError(requestId: string): { client?: ReturnType<typeof createClient>; error?: ApiError } {
  const url = process.env.NEXT_PUBLIC_SUPABASE_URL
  const key = process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY
  if (!url || !key) {
    return { error: { status: 500, code: 'env_missing', message: 'Supabase env not set', requestId } }
  }
  return { client: createClient(url, key, { global: { headers: { 'x-request-id': requestId } } }) }
}

export type ListOpenLoadsInput = {
  status?: 'open' | 'tendered' | 'covered' | 'cancelled'
  pickupFrom?: string
  pickupTo?: string
  origin?: string
  destination?: string
  equipment?: string
  limit?: number
  cursor?: { pickup_at: string; id: string } | null
}

export async function listOpenLoads(input: ListOpenLoadsInput = {}): Promise<ServiceResult<{ rows: (MarketplaceLoad & { pickup_at?: string | null; pay_usd?: number | null; broker_id?: string | null })[]; nextCursor: ListOpenLoadsInput['cursor'] }>> {
  const requestId = crypto.randomUUID()
  const { status = 'open', pickupFrom, pickupTo, origin, destination, equipment, limit = 50, cursor } = input
  try {
    const { client, error } = getClientOrError(requestId)
    if (error) return { data: null, error, requestId }

    let query = (client as any)!
      .from('marketplace_loads')
      .select('id,status,origin,destination,equipment,pickup_at,pay_usd,broker_id', { count: 'exact' })
      .eq('status', status)
      .order('pickup_at', { ascending: false })
      .order('id', { ascending: false })

    if (pickupFrom) query = query.gte('pickup_at', pickupFrom)
    if (pickupTo) query = query.lte('pickup_at', pickupTo)
    if (origin) query = query.ilike('origin', `%${origin}%`)
    if (destination) query = query.ilike('destination', `%${destination}%`)
    if (equipment) query = query.eq('equipment', equipment)

    if (cursor) {
      // Compound cursor: pickup_at desc, then id desc
      query = query.lt('pickup_at', cursor.pickup_at).limit(limit)
    } else {
      query = query.limit(limit)
    }

    const { data, error: qError, status: qStatus } = await query
    if (qError) return { data: null, error: normalizeError(qError, qStatus, requestId), requestId }

    const rows = (data ?? []) as any[]
    let nextCursor: ListOpenLoadsInput['cursor'] = null
    if (rows.length === limit) {
      const last = rows[rows.length - 1]
      nextCursor = { pickup_at: last.pickup_at, id: last.id }
    }

    return { data: { rows: rows as any, nextCursor }, error: null, requestId }
  } catch (err: any) {
    return { data: null, error: normalizeError(err, 500, requestId), requestId }
  }
}

export type ListMyOffersInput = { carrierId: string; limit?: number; cursor?: { created_at: string; id: string } | null }
export async function listMyOffers(input: ListMyOffersInput): Promise<ServiceResult<{ rows: (MarketplaceOffer & { load?: MarketplaceLoad | null; status?: string | null })[]; nextCursor: ListMyOffersInput['cursor'] }>> {
  const requestId = crypto.randomUUID()
  try {
    const { client, error } = getClientOrError(requestId)
    if (error) return { data: null, error, requestId }
    const { carrierId, limit = 50, cursor } = input

    let query = (client as any)!
      .from('v_marketplace_my_offers')
      .select('id,load_id,carrier_id,price,created_at,status, load:load_id(id,origin,destination,equipment,pickup_at)')
      .eq('carrier_id', carrierId)
      .order('created_at', { ascending: false })
      .order('id', { ascending: false })

    if (cursor) {
      query = query.lt('created_at', cursor.created_at).limit(limit)
    } else {
      query = query.limit(limit)
    }

    const { data, error: qError, status } = await query
    if (qError) return { data: null, error: normalizeError(qError, status, requestId), requestId }

    const rows = (data ?? []) as any[]
    let nextCursor: ListMyOffersInput['cursor'] = null
    if (rows.length === limit) {
      const last = rows[rows.length - 1]
      nextCursor = { created_at: last.created_at, id: last.id }
    }

    return { data: { rows: rows as any, nextCursor }, error: null, requestId }
  } catch (err: any) {
    return { data: null, error: normalizeError(err, 500, requestId), requestId }
  }
}

export type CreateOfferInput = { loadId: string; carrierId: string; driverId?: string | null; bidUsd: number; message?: string | null; idempotencyKey?: string | null }
export async function createOffer(input: CreateOfferInput): Promise<ServiceResult<{ offer: MarketplaceOffer; quote: QuoteEvent }>> {
  const requestId = crypto.randomUUID()
  try {
    const { client, error } = getClientOrError(requestId)
    if (error) return { data: null, error, requestId }

    // Fetch load for lane/equipment context
    const { data: load, error: lErr, status: lStatus } = await (client as any)!
      .from('marketplace_loads')
      .select('id,origin,destination,equipment')
      .eq('id', input.loadId)
      .single()
    if (lErr || !load) return { data: null, error: normalizeError(lErr, lStatus, requestId), requestId }

    // Insert offer
    const { data: offer, error: offerErr, status: offerStatus } = await (client as any)!
      .from('marketplace_offers')
      .insert({ load_id: input.loadId, carrier_id: input.carrierId, driver_id: input.driverId ?? null, price: input.bidUsd, message: input.message ?? null, metadata: input.idempotencyKey ? { idempotencyKey: input.idempotencyKey } : null }, { returning: 'representation' })
      .select('id,load_id,carrier_id,price,created_at')
      .single()
    if (offerErr || !offer) return { data: null, error: normalizeError(offerErr, offerStatus, requestId), requestId }

    // Insert quote event
    const lane = `${load.origin} → ${load.destination}`
    const { data: quote, error: qErr, status: qStatus } = await (client as any)!
      .from('quote_events')
      .insert({ side: 'carrier', lane, equipment: load.equipment ?? null, quoted_usd: input.bidUsd, won: false, metadata: input.idempotencyKey ? { idempotencyKey: input.idempotencyKey } : null })
      .select('id,load_id,broker_id,type,created_at')
      .single()
    if (qErr || !quote) return { data: null, error: normalizeError(qErr, qStatus, requestId), requestId }

    return { data: { offer: offer as MarketplaceOffer, quote: quote as QuoteEvent }, error: null, requestId }
  } catch (err: any) {
    return { data: null, error: normalizeError(err, 500, requestId), requestId }
  }
}

export type UpdateOfferStatusInput = { offerId: string; status: 'accepted' | 'rejected' }
export async function updateOfferStatus(input: UpdateOfferStatusInput): Promise<ServiceResult<MarketplaceOffer>> {
  const requestId = crypto.randomUUID()
  try {
    const { client, error } = getClientOrError(requestId)
    if (error) return { data: null, error, requestId }

    const { data, error: uErr, status } = await (client as any)!
      .from('marketplace_offers')
      .update({ status: input.status })
      .eq('id', input.offerId)
      .select('id,load_id,carrier_id,price,created_at')
      .single()
    if (uErr || !data) return { data: null, error: normalizeError(uErr, status, requestId), requestId }
    return { data: data as MarketplaceOffer, error: null, requestId }
  } catch (err: any) {
    return { data: null, error: normalizeError(err, 500, requestId), requestId }
  }
}

export type GetLanePriceInput = { lane: { origin: string; destination: string }; equipment?: string | null; date?: string | null }
export async function getLanePrice(input: GetLanePriceInput): Promise<ServiceResult<{ p50: number | null; p80: number | null; confidence?: number | null; source?: string | null; sample_size?: number | null }>> {
  const requestId = crypto.randomUUID()
  try {
    const { client, error } = getClientOrError(requestId)
    if (error) return { data: null, error, requestId }

    const { origin, destination } = input.lane
    let query = (client as any)!
      .from('market_rates_daily')
      .select('p50,p80,confidence,source,sample_size')
      .eq('origin', origin)
      .eq('destination', destination)
      .order('service_date', { ascending: false })
      .limit(1)

    if (input.equipment) query = query.eq('equipment', input.equipment)
    if (input.date) query = query.lte('service_date', input.date)

    const { data, error: qErr, status } = await query
    if (qErr) return { data: null, error: normalizeError(qErr, status, requestId), requestId }

    const row = data?.[0] as Partial<MarketRateDaily> | undefined
    return { data: { p50: row?.p50 ?? null, p80: row?.p80 ?? null, confidence: (row as any)?.confidence ?? null, source: (row as any)?.source ?? null, sample_size: (row as any)?.sample_size ?? null }, error: null, requestId }
  } catch (err: any) {
    return { data: null, error: normalizeError(err, 500, requestId), requestId }
  }
}

export type GetBrokerCreditInput = { brokerId: string }
export async function getBrokerCredit(input: GetBrokerCreditInput): Promise<ServiceResult<{ tier: string | null; d2p_days?: number | null; bond_ok?: boolean | null; insurance_ok?: boolean | null; updated_at?: string | null }>> {
  const requestId = crypto.randomUUID()
  try {
    const { client, error } = getClientOrError(requestId)
    if (error) return { data: null, error, requestId }

    const { data, error: qErr, status } = await client!
      .from('broker_credit')
      .select('tier,d2p_days,bond_ok,insurance_ok,updated_at')
      .eq('broker_id', input.brokerId)
      .limit(1)

    if (qErr) return { data: null, error: normalizeError(qErr, status, requestId), requestId }

    const row = (data?.[0] as any as BrokerCredit) || null
    return { data: row ? { tier: (row as any).tier ?? null, d2p_days: (row as any).d2p_days ?? null, bond_ok: (row as any).bond_ok ?? null, insurance_ok: (row as any).insurance_ok ?? null, updated_at: (row as any).updated_at ?? null } : { tier: null }, error: null, requestId }
  } catch (err: any) {
    return { data: null, error: normalizeError(err, 500, requestId), requestId }
  }
}
