import { makeApp, req, headersFor } from './helpers/testUtils';

describe('HOS: GET /api/hos/:driver_user_id', () => {
  const app = makeApp();

  it('403 without read:hos scope', async () => {
    const r = await req(app)
      .get('/api/hos/11111111-1111-1111-1111-111111111111')
      .set(headersFor([]));
    expect(r.status).toBe(403);
  });

  it('200 with read:hos scope', async () => {
    const r = await req(app)
      .get('/api/hos/11111111-1111-1111-1111-111111111111')
      .query({ from: '2025-01-01', to: '2025-01-07' })
      .set(headersFor(['read:hos']));
    expect(r.status).toBe(200);
    expect(r.body).toHaveProperty('logs');
    expect(Array.isArray(r.body.logs)).toBe(true);
  });
});
