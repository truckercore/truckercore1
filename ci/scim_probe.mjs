// ci/scim_probe.mjs
// Minimal SCIM CRUD probe for Users
import fetch from 'node-fetch';

const base = process.env.SCIM_USERS_URL; // e.g., https://.../functions/v1/scim-users?org_id=...
const token = process.env.SCIM_TOKEN;
if (!base || !token) { console.error('SCIM env missing'); process.exit(2); }

const headers = { 'content-type': 'application/scim+json', 'authorization': `Bearer ${token}` };

async function createUser() {
  const res = await fetch(base, { method: 'POST', headers, body: JSON.stringify({ userName: `probe+${Date.now()}@example.com`, emails: [{ value: `probe+${Date.now()}@example.com` }], name: { givenName: 'Probe', familyName: 'User' } }) });
  const etag = res.headers.get('etag');
  const body = await res.json().catch(()=> ({}));
  if (res.status !== 201 && res.status !== 200) throw new Error(`create failed ${res.status}`);
  return { id: body.id, etag };
}

async function patchDeactivate(id, etag) {
  const res = await fetch(`${base}/${id}`, { method: 'PATCH', headers: { ...headers, 'if-match': etag || 'W/"stub"' }, body: JSON.stringify({ Operations: [{ op: 'Replace', path: 'active', value: false }] }) });
  if (res.status >= 400) throw new Error(`patch failed ${res.status}`);
}

(async () => {
  const { id, etag } = await createUser();
  await patchDeactivate(id, etag);
  console.log('✅ SCIM probe ok');
})();
