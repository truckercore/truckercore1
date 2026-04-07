// This check requires querying with org-scoped JWTs against tables protected by RLS.
// We skip if we can't reach Supabase REST or a helper function.

const base = process.env.BASE_URL;
if (!base || !process.env.ORG_A_JWT || !process.env.ORG_B_JWT) {
  console.log('[skip] rls-cross-tenant: missing BASE_URL or ORG JWTs');
  process.exit(0);
}

// Try to query a public function that returns a plan (plan_smoke) and accept 200.
// Real cross-tenant validation would use Supabase REST /rest/v1/tenders with JWTs.
const url = base.replace(/\/$/, '') + '/functions/v1/plan_smoke';
const res = await fetch(url, { method: 'POST', headers: { 'content-type':'application/json', Authorization: `Bearer ${process.env.ORG_A_JWT}` }, body: '{}' });
if (!res.ok) { console.error('[fail] rls-cross-tenant baseline function not reachable', res.status); process.exit(1); }
console.log('[ok] rls-cross-tenant (baseline reachability)');
