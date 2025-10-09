import { verify, signV2, InMemoryReplayCache } from '../api/lib/webhook';

describe('webhook verify', () => {
  const body = JSON.stringify({ ok: true });
  const now = Math.floor(Date.now() / 1000);
  const method = 'POST';
  const path = '/api/hooks/test';
  const contentType = 'application/json';

  test('valid signature with current secret', () => {
    const secret = 's1';
    const sig = signV2(secret, String(now), method, path, body);
    const res = verify({ secret, headerSignature: sig, timestamp: String(now), rawBody: body, method, path, contentType, metricsLabel: 'test' });
    expect(res.ok).toBe(true);
  });

  test('reject invalid signature', () => {
    const secret = 's1';
    const sig = signV2(secret, String(now), method, path, body).replace(/.$/, '0');
    const res = verify({ secret, headerSignature: sig, timestamp: String(now), rawBody: body, method, path, contentType, metricsLabel: 'test' });
    expect(res.ok).toBe(false);
  });

  test('reject skew beyond 5 min', () => {
    const secret = 's1';
    const ts = String(now - 4000);
    const sig = signV2(secret, ts, method, path, body);
    const res = verify({ secret, headerSignature: sig, timestamp: ts, rawBody: body, method, path, contentType, metricsLabel: 'test' });
    expect(res.ok).toBe(false);
  });

  test('dual-secret rotation accepts next before expiry', () => {
    const currentSecret = 'cur';
    const nextSecret = 'next';
    const ts = String(now);
    const sig = signV2(nextSecret, ts, method, path, body);
    const res = verify({ currentSecret, nextSecret, nextSecretExpiresAt: now + 3600, headerSignature: sig, timestamp: ts, rawBody: body, method, path, contentType, metricsLabel: 'test' });
    expect(res.ok).toBe(true);
  });

  test('dual-secret rotation rejects next after expiry', () => {
    const currentSecret = 'cur';
    const nextSecret = 'next';
    const ts = String(now + 7200);
    const sig = signV2(nextSecret, ts, method, path, body);
    const res = verify({ currentSecret, nextSecret, nextSecretExpiresAt: now + 3600, headerSignature: sig, timestamp: ts, rawBody: body, method, path, contentType, metricsLabel: 'test' });
    expect(res.ok).toBe(false);
  });

  test('replay cache rejects duplicate sig', () => {
    const secret = 's1';
    const replay = new InMemoryReplayCache();
    const ts = String(now);
    const sig = signV2(secret, ts, method, path, body);
    const first = verify({ secret, headerSignature: sig, timestamp: ts, rawBody: body, method, path, contentType, replayCache: replay, metricsLabel: 'test' });
    expect(first.ok).toBe(true);
    const second = verify({ secret, headerSignature: sig, timestamp: ts, rawBody: body, method, path, contentType, replayCache: replay, metricsLabel: 'test' });
    expect(second.ok).toBe(false);
  });

  test('idempotency cache rejects duplicate key', () => {
    const secret = 's1';
    const cache = new InMemoryReplayCache();
    const ts = String(now);
    const sig = signV2(secret, ts, method, path, body);
    const first = verify({ secret, headerSignature: sig, timestamp: ts, rawBody: body, method, path, contentType, idempotencyKey: 'abc-123-xyz', idempotencyCache: cache, metricsLabel: 'test' });
    expect(first.ok).toBe(true);
    const second = verify({ secret, headerSignature: sig, timestamp: ts, rawBody: body, method, path, contentType, idempotencyKey: 'abc-123-xyz', idempotencyCache: cache, metricsLabel: 'test' });
    expect(second.ok).toBe(false);
  });
});
