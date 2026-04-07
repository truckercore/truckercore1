// api/middleware/guard.ts
// Simple role/feature guard with deny logging. Use in Express-style servers.
// guard(role, feature, traceId) => boolean

function checkRole(role: string, feature: string): boolean {
  // Minimal mapping; adapt as needed. Example:
  // - corp_admin allowed everywhere
  // - dispatcher can POST /promos (promotion operations)
  // - drivers blocked from admin areas
  if (!role) return false
  if (role === 'corp_admin') return true
  if (feature === 'admin:sso') return role === 'corp_admin'
  if (feature === 'promos:write') return role === 'dispatcher' || role === 'corp_admin'
  return false
}

export function guard(role: string, feature: string, traceId: string): boolean {
  const allowed = checkRole(role, feature)
  if (!allowed) {
    try {
      // eslint-disable-next-line no-console
      console.warn(
        JSON.stringify({ event: 'api_deny', feature, role, trace_id: traceId, ts: new Date().toISOString() })
      )
    } catch {
      /* ignore logging errors */
    }
    return false
  }
  return true
}

export { checkRole }
