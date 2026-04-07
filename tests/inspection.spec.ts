import { makeApp, req, headersFor, idemKey } from './helpers/testUtils';

describe('Inspection: POST /api/inspection', () => {
  const app = makeApp();
  const base = {
    vehicle_id: '22222222-2222-2222-2222-222222222222',
    type: 'pre_trip',
    defects: [{ component: 'Lights', severity: 'minor' }],
    certified_safe: true,
    signed_at: new Date().toISOString()
  };

  it('403 without write:inspection scope', async () => {
    const r = await req(app).post('/api/inspection').set(headersFor([])).send(base);
    expect(r.status).toBe(403);
  });

  it('200 with write:inspection and idempotent replay', async () => {
    const headers = headersFor(['write:inspection']);
    const key = idemKey('inspection-1');
    const r1 = await req(app).post('/api/inspection').set({ ...headers, 'Idempotency-Key': key }).send(base);
    expect(r1.status).toBe(200);

    const r2 = await req(app).post('/api/inspection').set({ ...headers, 'Idempotency-Key': key }).send(base);
    expect(r2.status).toBe(200);
    expect(r2.headers['x-idempotent-replay']).toBe('true');
  });
});
