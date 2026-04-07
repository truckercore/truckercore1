// deno-fns/admin_downloads_purge_cache.ts
// Endpoint: /admin/downloads/purge-cache?org_id=...
// Calls CDN/cache purge for an org namespace. Placeholder implementation.

Deno.serve(async (req) => {
  try {
    const url = new URL(req.url);
    const org = url.searchParams.get('org_id');
    if (!org) return new Response('org_id required', { status: 400 });

    // TODO: enforce corp_admin/support auth

    const CDN_PURGE_URL = Deno.env.get('CDN_PURGE_URL');
    const API_CACHE_PURGE_URL = Deno.env.get('API_CACHE_PURGE_URL');
    const payload = { namespace: `org:${org}` };

    try {
      if (CDN_PURGE_URL) await fetch(CDN_PURGE_URL, { method: 'POST', headers: { 'content-type': 'application/json' }, body: JSON.stringify(payload) });
      if (API_CACHE_PURGE_URL) await fetch(API_CACHE_PURGE_URL, { method: 'POST', headers: { 'content-type': 'application/json' }, body: JSON.stringify(payload) });
    } catch (_) { /* best-effort */ }

    return new Response('ok');
  } catch (e) {
    return new Response(String((e as any)?.message || e), { status: 400 });
  }
});
