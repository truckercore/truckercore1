// scripts/security/webhook_verify.mjs
// Safe additive webhook signature verification with a hardened variant + self-test.
// Usage: npm run security:verify-webhooks

import crypto from 'node:crypto';

export function verifySignature(secret, ts, rawBody) {
  const payload = `${ts}.${rawBody}`;
  const expected = crypto.createHmac('sha256', secret).update(payload).digest('hex');
  return `sha256=${expected}`;
}

export function timingSafeEqual(a, b) {
  const ba = Buffer.from(a || '');
  const bb = Buffer.from(b || '');
  if (ba.length !== bb.length) return false;
  return crypto.timingSafeEqual(ba, bb);
}

// Hardened verifier: constant-time compare + timestamp skew limit + optional replay guard hook.
export function verifySignatureSecure({
  secret,
  headerSignature,
  timestamp,
  rawBody,
  maxSkewSeconds = 300,
  isReplay,
}) {
  const nowSec = Math.floor(Date.now() / 1000);
  const tsSec = /^\d+$/.test(String(timestamp))
    ? parseInt(String(timestamp), 10)
    : Math.floor(new Date(timestamp).getTime() / 1000);
  if (!Number.isFinite(tsSec) || Math.abs(nowSec - tsSec) > maxSkewSeconds) {
    return false;
  }

  const payload = `${timestamp}.${rawBody}`;
  const mac = crypto.createHmac('sha256', secret).update(payload).digest('hex');
  const expected = `sha256=${mac}`;

  const a = Buffer.from(expected);
  const b = Buffer.from(headerSignature || '');
  if (a.length !== b.length || !crypto.timingSafeEqual(a, b)) {
    return false;
  }

  if (typeof isReplay === 'function') {
    const replayed = Boolean(isReplay(String(tsSec), expected));
    if (replayed) return false;
  }

  return true;
}

// Self-test runner when executed directly
if (import.meta.url === `file://${process.cwd().replace(/\\/g, '/')}/scripts/security/webhook_verify.mjs`) {
  const SECRET = 'test-secret';
  const raw = JSON.stringify({ hello: 'world' });
  const now = Math.floor(Date.now() / 1000);
  const sig = verifySignature(SECRET, String(now), raw);

  // Positive case
  const ok = verifySignatureSecure({
    secret: SECRET,
    headerSignature: sig,
    timestamp: String(now),
    rawBody: raw,
  });

  // Negative case: wrong signature
  const bad = verifySignatureSecure({
    secret: SECRET,
    headerSignature: sig.replace(/.$/, (c) => (c === '0' ? '1' : '0')),
    timestamp: String(now),
    rawBody: raw,
  });

  // Negative case: skewed timestamp
  const skewTs = String(now - 301);
  const skewSig = verifySignature(SECRET, skewTs, raw);
  const skew = verifySignatureSecure({
    secret: SECRET,
    headerSignature: skewSig,
    timestamp: skewTs,
    rawBody: raw,
  });

  // Replay cache demo
  const seen = new Set();
  const firstReplay = verifySignatureSecure({
    secret: SECRET,
    headerSignature: sig,
    timestamp: String(now),
    rawBody: raw,
    isReplay: (ts, signature) => {
      const key = `${ts}:${signature}`;
      if (seen.has(key)) return true;
      seen.add(key);
      return false;
    },
  });
  const secondReplay = verifySignatureSecure({
    secret: SECRET,
    headerSignature: sig,
    timestamp: String(now),
    rawBody: raw,
    isReplay: (ts, signature) => {
      const key = `${ts}:${signature}`;
      if (seen.has(key)) return true;
      seen.add(key);
      return false;
    },
  });

  const allGood = ok === true && bad === false && skew === false && firstReplay === true && secondReplay === false;
  if (!allGood) {
    console.error('[webhook_verify] Self-test failed', { ok, bad, skew, firstReplay, secondReplay });
    process.exit(1);
  } else {
    console.log('[webhook_verify] Self-test passed');
  }
}
