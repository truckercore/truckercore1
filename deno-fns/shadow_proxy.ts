// deno-fns/shadow_proxy.ts
const STAGING_READONLY_URL = Deno.env.get('STAGING_READONLY_URL')!;

Deno.serve(async (req) => {
  const clone = req.headers.get('X-Shadow-Clone') === '1';
  const url = new URL(req.url);
  const target = STAGING_READONLY_URL + url.pathname + url.search;
  const resp = await fetch(target, {
    method: req.method,
    headers: req.headers,
    body: req.body,
  });
  if (clone && (req.method === 'GET' || req.method === 'HEAD')) {
    // Fire-and-forget copy to staging
    fetch(target, { headers: req.headers }).catch(() => {});
  }
  return resp;
});
