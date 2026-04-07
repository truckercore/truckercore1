// deno-fns/lib/authz.ts
// Provider-side auth checks: validate org/role from JWT claims passed through headers.
export type AppJwt = { sub: string; app_org_id?: string; app_roles?: string[] }

export function requireOrgAndRole(req: Request, roles: string[] = []) {
  const auth = req.headers.get('Authorization') || ''
  const [, token] = auth.split(' ')
  if (!token) return { error: new Response(JSON.stringify({ error: 'unauthorized' }), { status: 401 }) }

  // In some edge runtimes, decoded JWT claims can be forwarded via a header
  const raw = req.headers.get('x-jwt-claims') // optional pass-through
  let claims: AppJwt | null = null
  try { claims = raw ? JSON.parse(raw) : null } catch {}
  if (!claims?.app_org_id) {
    return { error: new Response(JSON.stringify({ error: 'forbidden_org' }), { status: 403 }) }
  }
  if (roles.length > 0) {
    const has = (claims.app_roles || []).some(r => roles.includes(r))
    if (!has) return { error: new Response(JSON.stringify({ error: 'forbidden_role' }), { status: 403 }) }
  }
  return { claims }
}
