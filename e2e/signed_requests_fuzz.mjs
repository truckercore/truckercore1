import assert from "node:assert/strict";
import crypto from "node:crypto";

const FN_URL = process.env.FN_URL;
const SECRET = process.env.REQUEST_SIGNING_SECRET;

function sign(path, body, ts=new Date().toISOString()){
  const h = crypto.createHmac("sha256", SECRET).update(`${ts}|${path}|${body}`).digest("hex");
  return { ts, h, body };
}

if (!FN_URL || !SECRET) { console.log('[skip] signed_requests_fuzz: missing FN_URL or REQUEST_SIGNING_SECRET'); process.exit(0); }

test('signed requests fuzz', async () => {
  const goodBody = JSON.stringify({ ok: 1 });
  const { ts, h, body } = sign("/invoice_checkout", goodBody);

  const ok = await fetch(FN_URL, {
    method:"POST",
    headers: {"X-Timestamp":ts,"X-Signature":h,"Content-Type":"application/json"},
    body
  });
  assert.equal(ok.status < 400, true);

  const bad = await fetch(FN_URL.replace("/invoice_checkout","/other"), {
    method:"POST",
    headers: {"X-Timestamp":ts,"X-Signature":h,"Content-Type":"application/json"},
    body
  });
  assert.equal(bad.status >= 400, true);
});
