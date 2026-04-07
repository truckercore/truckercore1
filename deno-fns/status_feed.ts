// deno-fns/status_feed.ts
// JSON status feed with ETag / Last-Modified and short max-age caching.
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const URL = Deno.env.get("SUPABASE_URL")!;
const ANON = Deno.env.get("SUPABASE_ANON_KEY") || Deno.env.get("NEXT_PUBLIC_SUPABASE_ANON_KEY")!;
const db = createClient(URL, ANON, { auth: { persistSession: false }});

function toHex(buf: ArrayBuffer): string {
  return Array.from(new Uint8Array(buf)).map(b => b.toString(16).padStart(2,'0')).join('');
}

async function weakETagFrom(str: string) {
  const h = await crypto.subtle.digest("SHA-1", new TextEncoder().encode(str));
  return `W/"${toHex(h)}"`;
}

async function buildStatusJson() {
  const { data } = await db
    .from('status_incidents')
    .select('id,title,status,impact,started_at,resolved_at,updates')
    .order('started_at', { ascending: false })
    .limit(50);
  return { incidents: data || [] };
}

async function getLatestUpdateAt(): Promise<Date> {
  const { data } = await db
    .from('status_incidents')
    .select('started_at,resolved_at')
    .order('started_at', { ascending: false })
    .limit(1);
  const ts = data && data.length ? (data[0].resolved_at || data[0].started_at) : new Date().toISOString();
  return new Date(ts);
}

Deno.serve(async (req) => {
  const since = await getLatestUpdateAt();
  const payload = await buildStatusJson();
  const body = JSON.stringify(payload);
  const etag = await weakETagFrom(body);
  const inm = req.headers.get('If-None-Match');
  const ims = req.headers.get('If-Modified-Since');
  const lastMod = since.toUTCString();

  if ((inm && inm === etag) || (ims && new Date(ims) >= since)) {
    return new Response(null, { status: 304, headers: { 'ETag': etag, 'Last-Modified': lastMod, 'Cache-Control': 'public, max-age=60, s-maxage=60' }});
  }

  return new Response(body, {
    status: 200,
    headers: {
      'Content-Type': 'application/json',
      'ETag': etag,
      'Last-Modified': lastMod,
      'Cache-Control': 'public, max-age=60, s-maxage=60',
    }
  });
});
