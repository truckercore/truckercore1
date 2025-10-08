import { NextResponse } from 'next/server';
import { assertDbConfigured } from '../../../services/db/supabaseClient';

export const runtime = 'edge';

export async function GET() {
  const cfg = assertDbConfigured();
  // We don't perform a DB roundtrip here to keep it edge-compatible; this is a config health.
  // For a deeper check, create a Node runtime route and query a lightweight view.
  if (!cfg.ok) {
    return NextResponse.json({ status: 'ok', db: 'disabled', reason: cfg.reason }, { status: 200 });
  }
  return NextResponse.json({ status: 'ok', db: 'configured' }, { status: 200 });
}
