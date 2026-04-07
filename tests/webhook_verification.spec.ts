import { InMemoryReplayCache, verify, signV2, HEADER_IDEMP } from '../api/lib/webhook';

describe('webhook verification', () => {
  const SECRET = 'unit-secret';
  const body = JSON.stringify({ x: 1 });
  const method = 'POST';
  const path = '/webhooks/test';
  const contentType = 'application/json';

  test('accepts valid signature within skew', () => {
    const ts = Math.floor(Date.now() / 1000).toString();
    const sig = signV2(SECRET, ts, method, path, body);
    const res = verify({ secret: SECRET, headerSignature: sig, timestamp: ts, rawBody: body, method, path, contentType });
    expect(res.ok).toBe(true);
  });

  test('rejects timestamp older than 61s (past skew)', () => {
    const ts = Math.floor(Date.now() / 1000) - 61;
    const sig = signV2(SECRET, String(ts), method, path, body);
    const res = verify({ secret: SECRET, headerSignature: sig, timestamp: String(ts), rawBody: body, method, path, contentType, maxSkewSeconds: 60 });
    expect(res.ok).toBe(false);
  });

  test('rejects timestamp in the future by 61s (future skew)', () => {
    const ts = Math.floor(Date.now() / 1000) + 61;
    const sig = signV2(SECRET, String(ts), method, path, body);
    const res = verify({ secret: SECRET, headerSignature: sig, timestamp: String(ts), rawBody: body, method, path, contentType, maxSkewSeconds: 60 });
    expect(res.ok).toBe(false);
  });

  test('rejects invalid signature', () => {
    const ts = Math.floor(Date.now() / 1000).toString();
    const sig = signV2(SECRET, ts, method, path, body).replace(/.$/, (c) => (c === '0' ? '1' : '0'));
    const res = verify({ secret: SECRET, headerSignature: sig, timestamp: ts, rawBody: body, method, path, contentType });
    expect(res.ok).toBe(false);
  });

  test('rejects timestamp out of tolerance', () => {
    const ts = Math.floor(Date.now() / 1000) - 301;
    const sig = signV2(SECRET, String(ts), method, path, body);
    const res = verify({ secret: SECRET, headerSignature: sig, timestamp: String(ts), rawBody: body, method, path, contentType });
    expect(res.ok).toBe(false);
  });

  test('replay cache blocks second attempt', () => {
    const ts = Math.floor(Date.now() / 1000).toString();
    const sig = signV2(SECRET, ts, method, path, body);
    const cache = new InMemoryReplayCache();
    const first = verify({ secret: SECRET, headerSignature: sig, timestamp: ts, rawBody: body, method, path, contentType, replayCache: cache, replayTtlSeconds: 60 });
    const second = verify({ secret: SECRET, headerSignature: sig, timestamp: ts, rawBody: body, method, path, contentType, replayCache: cache, replayTtlSeconds: 60 });
    expect(first.ok).toBe(true);
    expect(second.ok).toBe(false);
  });

  test('idempotency header helper enforces requirements', async () => {
    const headers: Record<string, string> = {};
    headers[HEADER_IDEMP] = 'ABC-123-XYZ';
    const { requireIdempotencyKey } = await import('../api/lib/webhook');
    const res = requireIdempotencyKey(headers);
    expect(res.ok).toBe(true);
    expect(res.key).toBe('abc-123-xyz');
  });
  test('fails when path is wrong (bound in MAC)', () => {
    const ts = Math.floor(Date.now() / 1000).toString();
    const sig = signV2(SECRET, ts, method, path, body);
    const res = verify({ secret: SECRET, headerSignature: sig, timestamp: ts, rawBody: body, method, path: '/webhooks/other', contentType });
    expect(res.ok).toBe(false);
  });

  test('fails when body content swapped (canonical JSON)', () => {
    const ts = Math.floor(Date.now() / 1000).toString();
    const sig = signV2(SECRET, ts, method, path, JSON.stringify({ a: 1, b: 2 }));
    // Same fields, different order should not break because of canonicalization; change a value to ensure failure
    const res = verify({ secret: SECRET, headerSignature: sig, timestamp: ts, rawBody: JSON.stringify({ a: 2, b: 2 }), method, path, contentType });
    expect(res.ok).toBe(false);
  });

  test('accepts ISO8601 timestamp within skew', () => {
    const date = new Date();
    const ts = date.toISOString();
    const sec = Math.floor(date.getTime() / 1000).toString();
    const sig = signV2(SECRET, sec, method, path, body);
    const res = verify({ secret: SECRET, headerSignature: sig, timestamp: ts, rawBody: body, method, path, contentType });
    expect(res.ok).toBe(true);
  });

  test('rejects unsupported content-type', () => {
    const ts = Math.floor(Date.now() / 1000).toString();
    const sig = signV2(SECRET, ts, method, path, body);
    const res = verify({ secret: SECRET, headerSignature: sig, timestamp: ts, rawBody: body, method, path, contentType: 'text/plain' });
    expect(res.ok).toBe(false);
  });
});
