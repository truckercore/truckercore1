import { req, headersFor, idemKey } from './helpers/testUtils';

describe('Org enforcement: POST /api/ownerop/expenses', () => {
  const path = '/api/ownerop/expenses';
  const base = { category: 'fuel', amount_usd: 10, incurred_on: '2025-01-01' };
  const scopes = ['write:expenses'];
  const orgId = '00000000-0000-0000-0000-000000000001';

  it('400 when org context missing', async () => {
    const r = await req().post(path).set({ 'X-Api-Key': 'test:write:expenses' }).send(base);
    expect(r.status).toBe(400);
    expect(r.body).toMatchObject({ error: 'missing_org_context' });
  });

  it('403 when body.org_id mismatches resolved org', async () => {
    const headers = headersFor(scopes, orgId);
    const r = await req()
      .post(path)
      .set({ ...headers, 'Idempotency-Key': idemKey('mismatch') })
      .send({ ...base, org_id: '99999999-9999-9999-9999-999999999999' });
    expect(r.status).toBe(403);
    expect(r.body).toMatchObject({ error: 'org_mismatch' });
  });

  it('2xx when org is present and consistent (server injects org_id)', async () => {
    const headers = headersFor(scopes, orgId);
    const r = await req()
      .post(path)
      .set({ ...headers, 'Idempotency-Key': idemKey('ok') })
      .send({ ...base, org_id: orgId });
    expect([200, 201]).toContain(r.status);
  });
});
