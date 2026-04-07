import { makeApp, req, headersFor } from './helpers/testUtils';

describe('Analytics: GET /api/analytics/fleet', () => {
  const app = makeApp();
  const path = '/api/analytics/fleet';

  it('403 without read:analytics scope', async () => {
    const res = await req(app)
      .get(path)
      .query({ from: '2025-01-01', to: '2025-01-31' })
      .set(headersFor([]));
    expect(res.status).toBe(403);
    expect(res.body).toMatchObject({ error: 'forbidden_scope' });
  });

  it('200 with read:analytics scope', async () => {
    const res = await req(app)
      .get(path)
      .query({ from: '2025-01-01', to: '2025-01-31' })
      .set(headersFor(['read:analytics']));
    expect(res.status).toBe(200);
    expect(res.body).toHaveProperty('kpis');
    expect(res.body).toHaveProperty('series');
  });

  it('400 when missing required query params', async () => {
    const res = await req(app).get(path).set(headersFor(['read:analytics']));
    expect([400, 422]).toContain(res.status);
  });
});
