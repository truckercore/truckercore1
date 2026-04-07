import { hmacHex } from './_util.js';

if (!process.env.BASE_URL || !process.env.STRIPE_WEBHOOK_SECRET) {
  console.log('[skip] stripe-race: missing BASE_URL or STRIPE_WEBHOOK_SECRET');
  process.exit(0);
}
const base = process.env.BASE_URL.replace(/\/$/, '');
const secret = process.env.STRIPE_WEBHOOK_SECRET;

const evtId = 'evt_e2e_race_' + Math.random().toString(36).slice(2);
const event = { id: evtId, type: 'checkout.session.completed', data: { object: { id: 'cs_test_' + evtId } } };

async function sendOnce() {
  const body = JSON.stringify(event);
  const t = Math.floor(Date.now() / 1000);
  const sig = hmacHex(secret, `${t}.${body}`);
  const sigHeader = `t=${t},v1=${sig}`;
  const res = await fetch(`${base}/functions/v1/stripe_webhook`, {
    method: 'POST',
    headers: { 'Stripe-Signature': sigHeader, 'content-type': 'application/json' },
    body,
  });
  const text = await res.text();
  return { ok: res.ok, status: res.status, text, json: (()=>{ try{return JSON.parse(text);}catch{return {};}})() };
}

const results = await Promise.all(Array.from({ length: 10 }, () => sendOnce()));
if (results.some(r => !r.ok)) {
  console.error('[fail] some requests failed', results.map(r=>r.status));
  process.exit(1);
}
const dedupCount = results.filter(r => r.json && r.json.dedup === true).length;
if (dedupCount < 8) {
  console.error('[fail] expected at least 8 dedup responses; got', dedupCount);
  process.exit(1);
}
console.log('[ok] stripe-race passed with dedupCount=', dedupCount);
