import { NextRequest, NextResponse } from 'next/server'
import { createClient } from '@/lib/supabase/server'

export async function POST(_req: NextRequest) {
  const requestId = crypto.randomUUID()
  try {
    const client = await createClient()

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
