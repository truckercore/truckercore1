// supabase/functions/price_suggestions/guard.ts
// Simple org guard. In production, replace header read with proper JWT claims parsing.
export function requireOrg(headers: Headers, bodyOrgId: string | null) {
  const claimOrg = headers.get('x-app-org-id') || ''; // TODO: replace with JWT claim decode
  if (!bodyOrgId || !claimOrg || bodyOrgId !== claimOrg) {
    return {
      ok: false as const,
      res: new Response(
        JSON.stringify({ ok: false, error: 'forbidden_org' }),
        { status: 403, headers: { 'content-type': 'application/json' } },
      ),
    };
  }
  return { ok: true as const };
}
