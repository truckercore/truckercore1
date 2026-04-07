const base = process.env.BASE_URL;
if (!base) { console.log('[skip] signed-request-missing-sig: missing BASE_URL'); process.exit(0); }
const url = base.replace(/\/$/, '') + '/functions/v1/invoice_checkout';
const body = { invoiceId: 'x', lineItems: [], successUrl: 'https://x', cancelUrl: 'https://x' };
const res = await fetch(url, { method: 'POST', headers: { 'content-type':'application/json' }, body: JSON.stringify(body) });
if (res.status !== 401) {
  console.error('[fail] expected 401 for missing signature, got', res.status);
  process.exit(1);
}
console.log('[ok] signed-request-missing-sig');
