// Validate claim keys presence; surface potential drift (canary)

function decodeJwt(t) {
  const p = t.split('.')[1];
  const json = Buffer.from(p.replace(/-/g,'+').replace(/_/g,'/'), 'base64').toString('utf8');
  return JSON.parse(json);
}

if (!process.env.ORG_A_JWT) { console.log('[skip] claims-drift-canary: missing ORG_A_JWT'); process.exit(0); }
const payload = decodeJwt(process.env.ORG_A_JWT);
if (!('app_org_id' in payload) || !('app_role' in payload)) {
  console.error('[fail] missing expected claim keys in ORG_A_JWT');
  process.exit(1);
}
if ('app_org_id2' in payload) {
  console.error('[fail] unexpected drift key app_org_id2 present');
  process.exit(1);
}
console.log('[ok] claims-drift-canary');
