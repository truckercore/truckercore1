import { userClient, corsHeaders } from '../_shared/client.ts';
import { clientIp, checkRate } from '../_shared/rate_limit.ts';
import { withMiddleware } from '../_shared/middleware.ts';
import { opsLog } from '../_shared/opslog.ts';

export default Deno.serve(withMiddleware(async ({ req, token, orgId, traceId }) => {
  const origin = req.headers.get('origin') ?? undefined;
  const op = 'user-profile.get';
  const t0 = performance.now();

  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders(origin) });
  }

  // Basic IP rate limiting (~60/min per IP)
  const ip = clientIp(req);
  const rate = checkRate(ip, { limit: 60, windowMs: 60_000 });
  if (!rate.allowed) {
    await opsLog({ op, orgId, traceId, ok: false, ms: performance.now() - t0, status: 429, err: 'rate_limited' });
    return new Response(JSON.stringify({ error: 'rate_limited' }), { status: 429, headers: { ...corsHeaders(origin), 'content-type': 'application/json' } });
  }

  if (!token) {
    await opsLog({ op, orgId, traceId, ok: false, ms: performance.now() - t0, status: 401, err: 'missing_token' });
    return new Response(JSON.stringify({ error: 'missing token' }), { status: 401, headers: { ...corsHeaders(origin), 'content-type': 'application/json' } });
  }

  try {
    const supa = userClient(token);
    const { data: prof, error } = await supa.from('profiles').select('id,email,app_org_id').single();
    if (error) {
      await opsLog({ op, orgId, traceId, ok: false, ms: performance.now() - t0, status: 403, err: error.message });
      return new Response(JSON.stringify({ error: error.message }), { status: 403, headers: { ...corsHeaders(origin), 'content-type': 'application/json' } });
    }

    const org = (prof as any)?.app_org_id as string | undefined;
    if (!org) {
      await opsLog({ op, orgId: org, traceId, ok: false, ms: performance.now() - t0, status: 403, err: 'missing_org_claim' });
      return new Response(JSON.stringify({ error: 'missing_org_claim' }), { status: 403, headers: { ...corsHeaders(origin), 'content-type': 'application/json' } });
    }

    const { data } = await supa.from('profiles').select('id,email,app_org_id').eq('app_org_id', org).single();

    await opsLog({ op, orgId: org, traceId, ok: true, ms: performance.now() - t0, status: 200 });
    return new Response(JSON.stringify({ data }), {
      headers: { 'Content-Type': 'application/json', ...corsHeaders(origin), 'x-trace-id': traceId ?? '' },
      status: 200,
    });
  } catch (e) {
    await opsLog({ op, orgId, traceId, ok: false, ms: performance.now() - t0, status: 500, err: String(e) });
    return new Response(JSON.stringify({ error: 'internal_error' }), { status: 500, headers: { ...corsHeaders(origin), 'content-type': 'application/json' } });
  }
}));
