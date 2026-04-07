import { signV2, verify } from '../api/lib/webhook';

describe('red-team: cross-endpoint replay', () => {
  test('signature bound to path fails on different path', () => {
    const secret = 'rt-secret';
    const ts = Math.floor(Date.now()/1000).toString();
    const body = JSON.stringify({ x: 1 });
    const method = 'POST';
    const pathA = '/webhooks/a';
    const pathB = '/webhooks/b';
    const sig = signV2(secret, ts, method, pathA, body);
    const res = verify({ secret, headerSignature: sig, timestamp: ts, rawBody: body, method, path: pathB, contentType: 'application/json' });
    expect(res.ok).toBe(false);
  });
});
