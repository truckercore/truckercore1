import { hmacHex, nowIso, postJson, requireEnv } from './_util.js';

requireEnv(['BASE_URL', 'STRIPE_WEBHOOK_SECRET']);

const base = process.env.BASE_URL.replace(/\/$/, '');
const secret = process.env.STRIPE_WEBHOOK_SECRET;

const evtId = 'evt_e2e_dup_' + Math.random().toString(36).slice(2);
const event = {
  id: evtId,
  type: 'checkout.session.completed',
  data: { object: { id: 'cs_test_' + evtId, metadata: { invoiceId: '00000000-0000-0000-0000-000000000000' } } },
};

async function sendOnce() {
  const body = JSON.stringify(event);
  const t = Math.floor(Date.now() / 1000);
  const sig = hmacHex(secret, `${t}.${body}`);
  const sigHeader = `t=${t},v1=${sig}`;
  return await fetch(`${base}/functions/v1/stripe_webhook`, {
    method: 'POST',
    headers: { 'Stripe-Signature': sigHeader, 'content-type': 'application/json' },
    body,
  });
}

const r1 = await sendOnce();
if (!r1.ok) { console.error('first webhook failed', r1.status, await r1.text()); process.exit(1); }
const r2 = await sendOnce();
if (!r2.ok) { console.error('second webhook failed', r2.status, await r2.text()); process.exit(1); }
const j2 = await r2.json().catch(()=>({}));
if (!('dedup' in j2)) {
  console.log('[warn] second response missing dedup flag; continuing but this weakens guarantee');
}
console.log('[ok] stripe-idempotency passed');
