import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

export function requireMethod(req: Request, method: string) {
  if (req.method !== method) {
    return new Response("Method Not Allowed", { status: 405 });
  }
  return null;
}

export function json(data: unknown, status = 200, headers: HeadersInit = {}) {
  return new Response(JSON.stringify(data), {
    status,
    headers: { "content-type": "application/json", ...headers },
  });
}

// Auth wrapper: extracts Bearer token and decodes org claim (best-effort)
const SUPABASE_URL = Deno.env.get('SUPABASE_URL')!;
export function withAuth(handler: (ctx: { req: Request; token?: string; orgId?: string }) => Promise<Response> | Response) {
  return async (req: Request) => {
    const auth = req.headers.get('authorization') ?? '';
    const token = auth.startsWith('Bearer ') ? auth.slice(7) : undefined;
    let orgId: string | undefined;

    if (token) {
      const anonClient = createClient(SUPABASE_URL, 'anon', { auth: { persistSession: false } } as any);
      try {
        const { data } = await (anonClient.auth as any).getUser(token);
        orgId = (data?.user?.app_metadata?.app_org_id as string)
             || (data?.user?.user_metadata?.app_org_id as string)
             || undefined;
      } catch (_e) {
        orgId = undefined;
      }
    }

    const res = await handler({ req, token, orgId });
    const h = new Headers(res.headers);
    if (orgId) h.set('X-App-Org-Id', orgId);
    return new Response(await res.text(), { status: res.status, headers: h });
  };
}

// withMiddleware: wraps auth and also surfaces a traceId from headers.
export function withMiddleware(handler: (ctx: { req: Request; token?: string; orgId?: string; traceId?: string }) => Promise<Response> | Response) {
  return withAuth(async ({ req, token, orgId }) => {
    const traceId = req.headers.get('x-trace-id') ?? crypto.randomUUID();
    return await handler({ req, token, orgId, traceId });
  });
}
