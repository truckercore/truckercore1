// api/lib/service_guard.ts
// Guard to prevent over-permissive service role usage on user endpoints, especially in production.
// Usage: checkServiceRole(headers, { allowInProd: false }) => { ok, error? }

export function checkServiceRole(headers: Headers | Record<string, string | string[] | undefined>, opts?: { allowInProd?: boolean }) {
  const allowInProd = Boolean(opts?.allowInProd);

  function get(h: any, k: string): string | undefined {
    if (!h) return undefined;
    const v = (h.get ? h.get(k) : (h[k] as any));
    if (Array.isArray(v)) return v[0];
    return typeof v === 'string' ? v : undefined;
  }

  const auth = (get(headers as any, 'authorization') || '').toString();
  const svcEnv = process.env.SUPABASE_SERVICE_ROLE_KEY || process.env.SERVICE_ROLE_KEY || '';
  const isService = !!svcEnv && auth.toLowerCase().includes(svcEnv.toLowerCase());

  const env = (process.env.NODE_ENV || 'development').toLowerCase();
  if (env === 'production' && isService && !allowInProd) {
    return { ok: false as const, error: 'service_role_not_allowed_in_prod' };
  }
  return { ok: true as const };
}
