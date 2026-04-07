import { makeApp, req, headersFor, idemKey } from './helpers/testUtils';

describe('Alerts: POST /api/alerts/:id/ack', () => {
  const app = makeApp();
  const id = '33333333-3333-3333-3333-333333333333';

  it('403 without write:alerts scope', async () => {
    const r = await req(app).post(`/api/alerts/${id}/ack`).set(headersFor([])).send({});
    expect(r.status).toBe(403);
  });

  it('200 with write:alerts and idempotent replay', async () => {
    const headers = headersFor(['write:alerts']);
    const key = idemKey('ack-1');

    const r1 = await req(app).post(`/api/alerts/${id}/ack`).set({ ...headers, 'Idempotency-Key': key }).send({});
    expect(r1.status).toBe(200);
    expect(r1.body).toHaveProperty('acknowledged');

    const r2 = await req(app).post(`/api/alerts/${id}/ack`).set({ ...headers, 'Idempotency-Key': key }).send({});
    expect(r2.status).toBe(200);
    expect(r2.headers['x-idempotent-replay']).toBe('true');
  });
});
