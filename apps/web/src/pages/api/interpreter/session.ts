// apps/web/src/pages/api/interpreter/session.ts
import { NextResponse } from "next/server";

// Proxy to Edge Function to create interpreter session.
// Uses anon key only to call function endpoint (no sensitive actions returned).
export async function POST() {
  const url = process.env.NEXT_PUBLIC_SUPABASE_URL;
  const anon = process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY ?? process.env.SUPABASE_ANON_KEY;
  if (!url || !anon) {
    return NextResponse.json({ error: "Supabase env not configured" }, { status: 500 });
    }

  const r = await fetch(`${url}/functions/v1/interpreter`, {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      Authorization: `Bearer ${anon}`,
    },
    body: JSON.stringify({}),
  });

  if (!r.ok) {
    const text = await r.text();
    return NextResponse.json({ error: text }, { status: r.status });
  }
  const json = await r.json();
  return NextResponse.json(json);
}
