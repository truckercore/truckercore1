// scripts/probe_pos_hmac.mjs
import crypto from 'node:crypto';

const url = process.env.POS_WEBHOOK_URL;
const secret = process.env.POS_WEBHOOK_SECRET;
if (!url || !secret) {
  console.error("Set POS_WEBHOOK_URL and POS_WEBHOOK_SECRET");
  process.exit(1);
}
const payload = {
  event: "promo.approved",
  redemption_id: "test-" + Date.now(),
  org_id: process.env.ORG_ID || "00000000-0000-0000-0000-000000000000",
  location_id: process.env.LOCATION_ID || "00000000-0000-0000-0000-000000000000",
  promo_id: "00000000-0000-0000-0000-000000000000",
  subtotal_cents: 8500,
  discount_cents: 1000,
  pos_code: "TEST-DSL-100",
  occurred_at: new Date().toISOString()
};
const body = JSON.stringify(payload);
const ts = new Date().toISOString();
const sig = crypto.createHmac('sha256', secret).update(`${ts}.${body}`).digest('hex');
const res = await fetch(url, {
  method: 'POST',
  headers: {
    'Content-Type':'application/json',
    'X-Timestamp': ts,
    'X-Signature': `sha256=${sig}`,
    'X-Probe': 'true'
  },
  body
});
const text = await res.text();
if (!res.ok) {
  console.error(`[fail] ${res.status} ${text}`);
  process.exit(1);
}
console.log("[ok] webhook accepted:", text);
