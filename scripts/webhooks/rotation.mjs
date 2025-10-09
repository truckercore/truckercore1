// scripts/webhooks/rotation.mjs
// Dual-secret webhook verification helpers with rotation support and optional replay protection.
import crypto from 'node:crypto';

export function timingSafeEqual(a, b) {
  const ba = Buffer.from(a || '');
  const bb = Buffer.from(b || '');
  if (ba.length !== bb.length) return false;
  return crypto.timingSafeEqual(ba, bb);
}

export function signWithSecret(secret, ts, rawBody) {
  const payload = `${ts}.${rawBody}`;
  const mac = crypto.createHmac('sha256', secret).update(payload).digest('hex');
  return `sha256=${mac}`;
}

/**
 * Returns the set of valid secrets for verification in priority order.
 * Promotes secret_next in priority after cutoff (callers persist promotion in storage as needed).
 */
export function resolveVerificationSecrets(sub, now = new Date()) {
  const secrets = [];
  const next = sub?.secret_next ?? undefined;
  const cutoff = sub?.secret_next_expires_at ? new Date(sub.secret_next_expires_at) : undefined;
  if (next && cutoff) {
    if (now < cutoff) {
      secrets.push(sub.secret, next);
    } else {
      secrets.push(next, sub.secret);
    }
  } else if (sub?.secret) {
    secrets.push(sub.secret);
  }
  return secrets;
}

/**
 * Hardened verification of a webhook using multiple secrets (supports rotation),
 * timestamp skew checks, and optional replay guard.
 */
export function verifyIncomingWebhook(sub, headerSignature, timestamp, rawBody, opts = {}) {
  const { maxSkewSeconds = 300, isReplay } = opts;
  const nowSec = Math.floor(Date.now() / 1000);
  const tsSec = /^\d+$/.test(String(timestamp))
    ? parseInt(String(timestamp), 10)
    : Math.floor(new Date(timestamp).getTime() / 1000);
  if (!Number.isFinite(tsSec) || Math.abs(nowSec - tsSec) > maxSkewSeconds) {
    return false;
  }
  const secrets = resolveVerificationSecrets(sub);
  for (const s of secrets) {
    const expected = signWithSecret(s, timestamp, rawBody);
    if (timingSafeEqual(expected, headerSignature || '')) {
      if (typeof isReplay === 'function') {
        const seen = Boolean(isReplay(String(tsSec), expected, sub.id || ''));
        if (seen) return false;
      }
      return true;
    }
  }
  return false;
}
