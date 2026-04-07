import { req, headersFor, idemKey } from './helpers/testUtils';

describe('Org enforcement: POST /api/inspection', () => {
  const base = {
    vehicle_id: '22222222-2222-2222-2222-222222222222',
    type: 'pre_trip',
    defects: [{ component: 'Lights', severity: 'minor' }],
    certified_safe: true,
    signed_at: new Date().toISOString()
  };
  const scopes = ['write:inspection'];
  const orgId = '00000000-0000-0000-0000-000000000001';

  it('400 when org context missing', async () => {
    const r = await req().post('/api/inspection').send(base);
    expect(r.status).toBe(400);
  });

  it('403 when body.org_id mismatches resolved org', async () => {
    const headers = headersFor(scopes, orgId);
    const r = await req()
      .post('/api/inspection')
      .set({ ...headers, 'Idempotency-Key': idemKey('insp-mismatch') })
      .send({ ...base, org_id: '99999999-9999-9999-9999-999999999999' });
    expect(r.status).toBe(403);
    expect(r.body).toMatchObject({ error: 'org_mismatch' });
  });

  it('2xx when org is present and consistent', async () => {
    const headers = headersFor(scopes, orgId);
    const r = await req()
      .post('/api/inspection')
      .set({ ...headers, 'Idempotency-Key': idemKey('insp-ok') })
      .send({ ...base, org_id: orgId });
    expect([200, 201]).toContain(r.status);
  });
});
