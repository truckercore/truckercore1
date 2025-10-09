import { hmacHex } from './_util.js';

const base = process.env.BASE_URL;
const secret = process.env.REQUEST_SIGNING_SECRET;
if (!base || !secret) { console.log('[skip] signed-request-positive: missing BASE_URL or REQUEST_SIGNING_SECRET'); process.exit(0); }

const url = base.replace(/\/$/, '') + '/functions/v1/invoice_checkout';
const body = { invoiceId: '00000000-0000-0000-0000-000000000000', lineItems: [], successUrl: 'https://example/s', cancelUrl: 'https://example/c' };
const ts = new Date().toISOString();
const sig = hmacHex(secret, `${ts}|/functions/v1/invoice_checkout|${JSON.stringify(body)}`);

const res = await fetch(url, { method: 'POST', headers: { 'content-type':'application/json', 'X-Timestamp': ts, 'X-Signature': sig }, body: JSON.stringify(body) });
if (res.status === 401 || res.status === 403) {
  console.error('[fail] expected signature accepted, got', res.status, await res.text());
  process.exit(1);
}
console.log('[ok] signed-request-positive');
