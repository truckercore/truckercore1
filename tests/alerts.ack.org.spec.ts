import { req, headersFor, idemKey } from './helpers/testUtils';

describe('Org enforcement: POST /api/alerts/:id/ack', () => {
  const id = '33333333-3333-3333-3333-333333333333';
  const scopes = ['write:alerts'];
  const orgId = '00000000-0000-0000-0000-000000000001';

  it('400 when org context missing', async () => {
    const r = await req().post(`/api/alerts/${id}/ack`).send({});
    expect(r.status).toBe(400);
  });

  it('403 when body.org_id mismatches resolved org', async () => {
    const headers = headersFor(scopes, orgId);
    const r = await req()
      .post(`/api/alerts/${id}/ack`)
      .set({ ...headers, 'Idempotency-Key': idemKey('ack-mismatch') })
      .send({ org_id: '99999999-9999-9999-9999-999999999999' });
    expect(r.status).toBe(403);
    expect(r.body).toMatchObject({ error: 'org_mismatch' });
  });

  it('2xx when org is present and consistent', async () => {
    const headers = headersFor(scopes, orgId);
    const r = await req()
      .post(`/api/alerts/${id}/ack`)
      .set({ ...headers, 'Idempotency-Key': idemKey('ack-ok') })
      .send({ org_id: orgId });
    expect([200, 204]).toContain(r.status);
  });
});
