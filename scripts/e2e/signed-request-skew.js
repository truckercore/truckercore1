import { hmacHex } from './_util.js';

const base = process.env.BASE_URL;
const secret = process.env.REQUEST_SIGNING_SECRET;
if (!base || !secret) { console.log('[skip] signed-request-skew: missing BASE_URL or REQUEST_SIGNING_SECRET'); process.exit(0); }
const url = base.replace(/\/$/, '') + '/functions/v1/invoice_checkout';
const body = { invoiceId: 'x', lineItems: [], successUrl: 'https://x', cancelUrl: 'https://x' };
const ts = new Date(Date.now() - 10 * 60 * 1000).toISOString(); // 10 minutes ago
const sig = hmacHex(secret, `${ts}|/functions/v1/invoice_checkout|${JSON.stringify(body)}`);
const res = await fetch(url, { method: 'POST', headers: { 'content-type':'application/json', 'X-Timestamp': ts, 'X-Signature': sig }, body: JSON.stringify(body) });
if (res.status !== 401) {
  console.error('[fail] expected 401 for skew, got', res.status);
  process.exit(1);
}
console.log('[ok] signed-request-skew');
