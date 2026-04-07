# Webhooks Integration Guide

## Delivery
- HTTP POST JSON to your endpoint.
- Headers:
  - X-TruckerCore-Timestamp: Unix seconds
  - X-TruckerCore-Signature: HMAC-SHA256(secret, `${ts}.${body}`)
  - X-TruckerCore-Signature-Alt: present during secret overlap (signing with next secret)
  - Idempotency-Key: unique per event; use to dedupe.
- Retries:
  - 5xx retried with exponential backoff + jitter.
  - 429 honored via Retry-After.
  - Hard 4xx not retried.

## Signature Verification
- Compute HMAC over `${timestamp}.${rawBody}` using your secret.
- Accept timestamps within ±5 minutes.
- During rotations, Signature-Alt is also sent (valid with upcoming secret).
- Use the SDK helper verifyWebhookSignature() as a starting point.

## Idempotency
- Store processed Idempotency-Key for 24–72 hours.
- On duplicate, return 2xx; do not reprocess.

## Ordering
- Ordering is best-effort within an aggregate_id by created_at.
- Maintain last-seen per aggregate; discard stale events; optionally reorder with small buffers.

## Sample Receiver (Node)
```ts
import express from 'express';
import { verifyWebhookSignature } from '@truckercore/sdk';

const app = express();
app.use(express.json({ verify: (req: any, _res, buf) => { req.rawBody = buf.toString('utf8'); } }));

app.post('/webhooks', (req, res) => {
  const ts = req.header('X-TruckerCore-Timestamp') || '';
  const sig = req.header('X-TruckerCore-Signature') || '';
  const ok = verifyWebhookSignature({
    secret: process.env.WEBHOOK_SECRET!,
    timestamp: ts,
    bodyRaw: (req as any).rawBody,
    signature: sig,
  });
  if (!ok) return res.status(401).json({ error: 'invalid_signature' });
  // idempotency key
  const idem = req.header('Idempotency-Key');
  // ... handle event; ensure dedupe on idem ...
  res.json({ ok: true });
});
```
