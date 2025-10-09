import { NextRequest, NextResponse } from 'next/server'
import { createClient } from '@supabase/supabase-js'

function getClient(requestId: string) {
  const url = process.env.NEXT_PUBLIC_SUPABASE_URL
  const key = process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY
  if (!url || !key) return null
  return createClient(url, key, { global: { headers: { 'x-request-id': requestId } } })
}

export async function GET(_req: NextRequest) {
  const requestId = crypto.randomUUID()
  try {
    const client = getClient(requestId)
    if (!client) return NextResponse.json({ error: { status: 500, code: 'env_missing', message: 'Supabase env not set', requestId } }, { status: 500 })
    const { data, error, status } = await client.from('feature_flags').select('key,enabled').eq('key','safety_export_enabled').maybeSingle()
    if (error) return NextResponse.json({ error: { status: status ?? 500, code: error.code, message: error.message, requestId } }, { status: status ?? 500 })
    const enabled = !!data?.enabled
    return NextResponse.json({ ok: true, enabled, requestId })
  } catch (err:any) {
    return NextResponse.json({ error: { status: 500, code: err?.code ?? 'unknown', message: err?.message ?? 'Unexpected error', requestId } }, { status: 500 })
  }
}
