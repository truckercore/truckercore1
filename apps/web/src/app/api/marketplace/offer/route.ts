import { NextRequest, NextResponse } from 'next/server'
import { createClient } from '@supabase/supabase-js'

function getClient(requestId: string) {
  const url = process.env.NEXT_PUBLIC_SUPABASE_URL
  const key = process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY
  if (!url || !key) return null
  return createClient(url, key, { global: { headers: { 'x-request-id': requestId } } })
}

export async function POST(req: NextRequest) {
  const requestId = crypto.randomUUID()
  try {
    const body = await req.json()
    const { loadId, carrierId, driverId, bidUsd, message, idempotencyKey } = body || {}
    if (!loadId || !carrierId || typeof bidUsd !== 'number') {
      return NextResponse.json({ error: { status: 400, code: 'invalid_payload', message: 'loadId, carrierId and bidUsd are required', requestId } }, { status: 400, headers: { 'x-request-id': requestId } })
    }

    const client = getClient(requestId)
    if (!client) {
      return NextResponse.json({ error: { status: 500, code: 'env_missing', message: 'Supabase env not set', requestId } }, { status: 500, headers: { 'x-request-id': requestId } })
    }

    const { data: load, error: lErr, status: lStatus } = await client
      .from('marketplace_loads')
      .select('id,origin,destination,equipment')
      .eq('id', loadId)
      .single()
    if (lErr || !load) {
      return NextResponse.json({ error: { status: lStatus ?? 500, code: lErr?.code, message: lErr?.message ?? 'Load not found', requestId } }, { status: lStatus ?? 500, headers: { 'x-request-id': requestId } })
    }

    const { data: offer, error: oErr, status: oStatus } = await client
      .from('marketplace_offers')
      .insert({ load_id: loadId, carrier_id: carrierId, driver_id: driverId ?? null, price: bidUsd, message: message ?? null, metadata: idempotencyKey ? { idempotencyKey } : null })
      .select('id,load_id,carrier_id,price,created_at')
      .single()
    if (oErr || !offer) {
      return NextResponse.json({ error: { status: oStatus ?? 500, code: oErr?.code, message: oErr?.message ?? 'Offer failed', requestId } }, { status: oStatus ?? 500, headers: { 'x-request-id': requestId } })
    }

    const lane = `${load.origin} → ${load.destination}`
    const { data: quote, error: qErr, status: qStatus } = await client
      .from('quote_events')
      .insert({ side: 'carrier', lane, equipment: load.equipment ?? null, quoted_usd: bidUsd, won: false, metadata: idempotencyKey ? { idempotencyKey } : null })
      .select('id,load_id,broker_id,type,created_at')
      .single()
    if (qErr || !quote) {
      return NextResponse.json({ error: { status: qStatus ?? 500, code: qErr?.code, message: qErr?.message ?? 'Quote event failed', requestId } }, { status: qStatus ?? 500, headers: { 'x-request-id': requestId } })
    }

    return NextResponse.json({ data: { offer, quote }, requestId }, { status: 200, headers: { 'x-request-id': requestId } })
  } catch (err: any) {
    return NextResponse.json({ error: { status: 500, code: err?.code ?? 'unknown', message: err?.message ?? 'Unexpected error', requestId } }, { status: 500, headers: { 'x-request-id': requestId } })
  }
}
