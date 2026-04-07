// tests/privacy.subscriptions.spec.ts
import { req, headersFor } from './helpers/testUtils';

describe('Privacy: list subscriptions (redacted)', () => {
  it('200 and secrets redacted', async () => {
    const orgId = '00000000-0000-0000-0000-000000000001';
    const r = await req()
      .get(`/v1/orgs/${orgId}/privacy/subscriptions`)
      .set(headersFor(['read:analytics'], orgId));
    expect(r.status).toBe(200);
    expect(Array.isArray(r.body)).toBe(true);
    if (r.body.length) {
      expect(r.body[0]).not.toHaveProperty('secret');
      expect(r.body[0]).toHaveProperty('endpoint_url');
      expect(r.body[0]).toHaveProperty('topics');
    }
  });
});
