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
    const { action, target, status, details } = body || {}

    if (!action) {
      return NextResponse.json({ error: { status: 400, code: 'invalid_payload', message: 'action is required', requestId } }, { status: 400, headers: { 'x-request-id': requestId } })
    }

    const client = getClient(requestId)
    if (!client) {
      return NextResponse.json({ error: { status: 500, code: 'env_missing', message: 'Supabase env not set', requestId } }, { status: 500, headers: { 'x-request-id': requestId } })
    }

    const { error: qErr, status: qStatus } = await client
      .from('audit_log')
      .insert({ action, target: target ?? null, status: status ?? 'ok', request_id: requestId, details: details ?? null })

    if (qErr) {
      return NextResponse.json({ error: { status: qStatus ?? 500, code: qErr?.code, message: qErr?.message ?? 'Audit insert failed', requestId } }, { status: qStatus ?? 500, headers: { 'x-request-id': requestId } })
    }

    return NextResponse.json({ ok: true, requestId }, { status: 200, headers: { 'x-request-id': requestId } })
  } catch (err: any) {
    return NextResponse.json({ error: { status: 500, code: err?.code ?? 'unknown', message: err?.message ?? 'Unexpected error', requestId } }, { status: 500, headers: { 'x-request-id': requestId } })
  }
}
