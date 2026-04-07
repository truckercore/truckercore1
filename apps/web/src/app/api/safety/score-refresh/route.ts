import { NextRequest, NextResponse } from 'next/server'
import { createClient } from '@supabase/supabase-js'

function getClient(requestId: string) {
  const url = process.env.NEXT_PUBLIC_SUPABASE_URL
  const key = process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY
  if (!url || !key) return null
  return createClient(url, key, { global: { headers: { 'x-request-id': requestId } } })
}

export async function POST(_req: NextRequest) {
  const requestId = crypto.randomUUID()
  try {
    const client = getClient(requestId)
    if (!client) {
      return NextResponse.json({ error: { status: 500, code: 'env_missing', message: 'Supabase env not set', requestId } }, { status: 500, headers: { 'x-request-id': requestId } })
    }

    // Call the refresh function. Prefer RPC if exposed, otherwise select from function via SQL view/SECURITY DEFINER function name
    const { data, error, status } = await (client as any)
      .rpc('refresh_safety_scores')

    if (error) {
      return NextResponse.json({ error: { status: status ?? 500, code: error.code, message: error.message ?? 'Failed to refresh', requestId } }, { status: status ?? 500, headers: { 'x-request-id': requestId } })
    }

    const count_updated = typeof data === 'number' ? data : (data?.count ?? null)
    return NextResponse.json({ ok: true, count_updated, requestId }, { status: 200, headers: { 'x-request-id': requestId } })
  } catch (err: any) {
    return NextResponse.json({ error: { status: 500, code: err?.code ?? 'unknown', message: err?.message ?? 'Unexpected error', requestId } }, { status: 500, headers: { 'x-request-id': requestId } })
  }
}
