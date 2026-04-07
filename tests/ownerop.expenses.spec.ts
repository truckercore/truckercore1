import { makeApp, req, headersFor, idemKey } from './helpers/testUtils';

describe('OwnerOp: POST /api/ownerop/expenses', () => {
  const app = makeApp();
  const path = '/api/ownerop/expenses';
  const headers = headersFor(['write:expenses']);

  const body = {
    category: 'fuel',
    amount_usd: 123.45,
    incurred_on: '2025-01-15'
  };

  it('403 without write:expenses scope', async () => {
    const r = await req(app).post(path).set(headersFor([])).send(body);
    expect(r.status).toBe(403);
  });

  it('200 create with idempotent replay on duplicate', async () => {
    const key = idemKey('ownerop-fuel');
    const r1 = await req(app).post(path).set({ ...headers, 'Idempotency-Key': key }).send(body);
    expect([200, 201]).toContain(r1.status);

    const r2 = await req(app).post(path).set({ ...headers, 'Idempotency-Key': key }).send(body);
    expect([200, 201]).toContain(r2.status);
    expect(r2.headers['x-idempotent-replay']).toBe('true');
    expect(r2.body).toMatchObject(r1.body);
  });

  it('409 on idempotency key collision (same key, different body)', async () => {
    const key = idemKey('ownerop-collision');
    const r1 = await req(app).post(path).set({ ...headers, 'Idempotency-Key': key }).send(body);
    expect([200, 201]).toContain(r1.status);

    const r2 = await req(app).post(path).set({ ...headers, 'Idempotency-Key': key }).send({ ...body, amount_usd: 999 });
    expect(r2.status).toBe(409);
    expect(r2.body).toMatchObject({ error: 'idempotency_key_collision' });
  });
});
