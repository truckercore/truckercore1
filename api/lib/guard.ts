// api/lib/guard.ts
// Org-scope and role guard helper for Node/Express-style APIs.
// Ensures the request headers include x-app-org-id matching the body/org param and,
// optionally, that at least one of the allowed roles is present in x-app-roles (JSON array).

export function ensureOrgScope(headers: Headers | Record<string, string | string[] | undefined>, bodyOrgId: string | null, allowedRoles: string[] = []) {
  function get(h: any, k: string): string | undefined {
    if (!h) return undefined
    const v = (h.get ? h.get(k) : (h[k] as any))
    if (Array.isArray(v)) return v[0]
    return typeof v === 'string' ? v : undefined
  }

  const claimOrg = (get(headers as any, 'x-app-org-id') || '').toString()
  const rolesRaw = (get(headers as any, 'x-app-roles') || '[]').toString()
  let roles: string[] = []
  try { roles = JSON.parse(rolesRaw) } catch { roles = [] }

  if (!bodyOrgId || !claimOrg || bodyOrgId !== claimOrg) {
    return { ok: false as const, res: new Response(JSON.stringify({ ok: false, error: 'forbidden_org' }), { status: 403, headers: { 'content-type': 'application/json' } }) }
  }
  if (allowedRoles.length && !roles.some(r => allowedRoles.includes(r))) {
    return { ok: false as const, res: new Response(JSON.stringify({ ok: false, error: 'forbidden_role' }), { status: 403, headers: { 'content-type': 'application/json' } }) }
  }
  return { ok: true as const }
}
