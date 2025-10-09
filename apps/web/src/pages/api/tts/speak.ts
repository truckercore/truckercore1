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
  try {
    const { text, locale, voice, rate } = await req.json();
    const backend = process.env.TTS_BACKEND_URL;
    if (!backend) return new NextResponse('Missing TTS_BACKEND_URL', { status: 500 });
    const r = await fetch(backend, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ text, locale, voice, rate }),
    });
    return new NextResponse(r.body, { status: r.status, headers: { 'Content-Type': r.headers.get('content-type') ?? 'audio/wav' }});
  } catch (e: any) {
    return new NextResponse(String(e?.message || e), { status: 500 });
  }
}
