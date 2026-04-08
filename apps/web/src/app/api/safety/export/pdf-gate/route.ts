import { NextRequest, NextResponse } from 'next/server'
import { createClient } from '@/lib/supabase/server'

export async function GET(_req: NextRequest) {
  const requestId = crypto.randomUUID()
  try {
    const client = await createClient()

    const { data, error, status } = await client.from('feature_flags').select('key,enabled').eq('key','safety_export_enabled').maybeSingle()
    if (error) return NextResponse.json({ error: { status: status ?? 500, code: error.code, message: error.message, requestId } }, { status: status ?? 500 })
    const enabled = !!data?.enabled
    return NextResponse.json({ ok: true, enabled, requestId })
  } catch (err:any) {
    return NextResponse.json({ error: { status: 500, code: err?.code ?? 'unknown', message: err?.message ?? 'Unexpected error', requestId } }, { status: 500 })
  }
}
