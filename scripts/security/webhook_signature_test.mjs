#!/usr/bin/env node
/*
Simple webhook signature self-test:
- Computes HMAC SHA256 of a sample payload with a sample secret
- Verifies signature match logic and writes a short report to webhook_sig_test.txt
*/

import crypto from 'crypto';
import fs from 'fs';

const secret = process.env.WEBHOOK_TEST_SECRET || 'test_secret_key';
const payload = JSON.stringify({ event: 'test', ts: new Date().toISOString() });
const sig = crypto.createHmac('sha256', secret).update(payload).digest('hex');

// Verification (constant-time compare)
function safeEqual(a, b) {
  const ba = Buffer.from(a);
  const bb = Buffer.from(b);
  if (ba.length !== bb.length) return false;
  return crypto.timingSafeEqual(ba, bb);
}

const ok = safeEqual(sig, crypto.createHmac('sha256', secret).update(payload).digest('hex'));
const out = `webhook self-test\nsecret_len=${secret.length}\npayload_len=${payload.length}\nsignature=${sig}\nverify=${ok}`;
fs.writeFileSync('webhook_sig_test.txt', out, 'utf8');
console.log(out);
