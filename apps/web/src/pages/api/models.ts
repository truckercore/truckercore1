import { NextRequest, NextResponse } from 'next/server';
export async function GET(_req: NextRequest) {
  const r = await fetch(process.env.NEXT_PUBLIC_SUPABASE_URL + '/functions/v1/model-manifest', {
    headers: { 'Authorization': `Bearer ${process.env.SUPABASE_ANON_KEY || process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY}` }
  });
  return NextResponse.json(await r.json(), { status: r.status });
}
