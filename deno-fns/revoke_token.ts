// deno-fns/revoke_token.ts
// Endpoint: /api/downloads/revoke (POST)
// Body: { token_id: string, cdn_urls?: string[], api_paths?: string[] }
// Marks token as revoked and attempts best-effort cache purges.
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const URL = Deno.env.get("SUPABASE_URL")!;
const KEY = Deno.env.get("SUPABASE_SERVICE_ROLE")!;
const db = createClient(URL, KEY, { auth: { persistSession: false }});

async function purge(cdnUrls: string[] = [], apiPaths: string[] = []) {
  for (const u of cdnUrls) {
    try { await fetch(String(Deno.env.get('CDN_PURGE_URL') || 'https://cdn-api/purge'), { method: 'POST', headers: { 'content-type': 'application/json' }, body: JSON.stringify({ url: u }) }); } catch (_) {}
  }
  for (const p of apiPaths) {
    try { await fetch(String(Deno.env.get('API_CACHE_PURGE_URL') || 'https://api-cache/purge'), { method: 'POST', headers: { 'content-type': 'application/json' }, body: JSON.stringify({ path: p }) }); } catch (_) {}
  }
}

Deno.serve(async (req) => {
  if (req.method !== 'POST') return new Response('Method Not Allowed', { status: 405 });
  try {
    const { token_id, cdn_urls, api_paths } = await req.json();
    if (!token_id) return new Response('token_id required', { status: 400 });
    const { error } = await db.from('download_tokens').update({ status: 'revoked' }).eq('token_id', token_id);
    if (error) return new Response(error.message, { status: 500 });
    await purge(Array.isArray(cdn_urls) ? cdn_urls : [], Array.isArray(api_paths) ? api_paths : []);
    return new Response(JSON.stringify({ ok: true }), { headers: { 'content-type': 'application/json' } });
  } catch (e) {
    return new Response(String((e as any)?.message || e), { status: 400 });
  }
});