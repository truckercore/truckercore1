import { NextRequest, NextResponse } from 'next/server';

// Simple in-memory rate limiter (per instance)
const windowMs = 60_000;
const maxReq = 30;
const bucket = new Map<string, number[]>();
function rateLimit(key: string) {
  const now = Date.now();
  const arr = bucket.get(key) ?? [];
  const recent = arr.filter(ts => now - ts < windowMs);
  if (recent.length >= maxReq) return false;
  recent.push(now);
  bucket.set(key, recent);
  return true;
}

export async function POST(req: NextRequest) {
  if (!rateLimit(req.ip ?? 'anon')) return new NextResponse('Rate limit exceeded', { status: 429 });
  // Enforce default offline ASR policy unless explicitly allowed by org policy header
  const allowCloud = req.headers.get('x-org-allow-cloud-asr') === 'true';
  if (!allowCloud) return new NextResponse('Cloud ASR disabled by policy', { status: 403 });

  try {
    const form = await req.formData();
    const res = await fetch(process.env.NEXT_PUBLIC_SUPABASE_URL + '/functions/v1/asr-transcribe', {
      method: 'POST',
      headers: { 'Authorization': `Bearer ${process.env.SUPABASE_ANON_KEY || process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY}` },
      body: form as any,
    });
    const ct = res.headers.get('content-type') || '';
    const body = ct.includes('application/json') ? await res.json() : await res.text();
    return NextResponse.json(body as any, { status: res.status });
  } catch (e: any) {
    return NextResponse.json({ error: String(e?.message || e) }, { status: 500 });
  }
}
