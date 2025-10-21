import { NextResponse } from 'next/server'

// TODO: Configure Supabase and real insurance quoting before enabling this endpoint
export async function POST() {
  return NextResponse.json(
    { error: 'Insurance API not configured yet' },
    { status: 501 }
  )
}
