// tests/privacy.audit.spec.ts
import { req, headersFor } from './helpers/testUtils';

describe('Privacy: access audit export', () => {
  it('200 CSV for org scope only', async () => {
    const orgId = '00000000-0000-0000-0000-000000000001';
    const r = await req()
      .get(`/v1/orgs/${orgId}/privacy/access-audit.csv`)
      .query({ from: '2025-01-01', to: '2025-01-31' })
      .set(headersFor(['read:analytics'], orgId));
    expect(r.status).toBe(200);
    expect(r.headers['content-type']).toMatch(/text\/csv/);
  });

  it('403 without correct org scope (mismatch path vs header)', async () => {
    const r = await req()
      .get('/v1/orgs/99999999-9999-9999-9999-999999999999/privacy/access-audit.csv')
      .query({ from: '2025-01-01', to: '2025-01-31' })
      .set(headersFor(['read:analytics'], '00000000-0000-0000-0000-000000000001'));
    expect([400, 403]).toContain(r.status);
  });
});
