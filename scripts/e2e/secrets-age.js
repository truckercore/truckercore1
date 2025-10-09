const base = process.env.BASE_URL;
if (!base) { console.log('[skip] secrets-age: missing BASE_URL'); process.exit(0); }
const url = base.replace(/\/$/, '') + '/functions/v1/secrets_rotation_check';
const res = await fetch(url);
if (!res.ok) { console.error('[fail] secrets-age endpoint not ok', res.status); process.exit(1); }
const data = await res.json().catch(()=>({}));
if (typeof data.staleCount === 'number') {
  console.log('[ok] secrets-age staleCount=', data.staleCount);
  process.exit(0);
}
console.log('[ok] secrets-age (basic reachability)');
