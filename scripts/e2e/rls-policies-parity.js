const base = process.env.BASE_URL;
if (!base) { console.log('[skip] rls-policies-parity: missing BASE_URL'); process.exit(0); }
const url = base.replace(/\/$/, '') + '/functions/v1/rls_policy_check';
const res = await fetch(url);
if (!res.ok) { console.error('[fail] rls-policies-parity endpoint not ok', res.status); process.exit(1); }
const data = await res.json().catch(()=>({}));
if (data && typeof data.checked === 'number') {
  console.log('[ok] rls-policies-parity checked=', data.checked, 'failures=', data.failures);
  if ((data.failures ?? 0) > 0) { console.error('[fail] RLS failures reported'); process.exit(1); }
  process.exit(0);
}
console.log('[ok] rls-policies-parity (basic reachability)');
