import { hmacHex } from './_util.js';

const base = process.env.BASE_URL;
const secret = process.env.REQUEST_SIGNING_SECRET;
if (!base || !secret) { console.log('[skip] signed-request-path-tamper: missing BASE_URL or REQUEST_SIGNING_SECRET'); process.exit(0); }

const signedPath = '/functions/v1/invoice_checkout';
const sendPath = '/functions/v1/plan_smoke';
const url = base.replace(/\/$/, '') + sendPath;
const body = { foo: 'bar' };
const ts = new Date().toISOString();
const sig = hmacHex(secret, `${ts}|${signedPath}|${JSON.stringify(body)}`);
const res = await fetch(url, { method: 'POST', headers: { 'content-type':'application/json', 'X-Timestamp': ts, 'X-Signature': sig }, body: JSON.stringify(body) });
if (res.status !== 401) {
  console.error('[fail] expected 401 for path tamper, got', res.status);
  process.exit(1);
}
console.log('[ok] signed-request-path-tamper');
