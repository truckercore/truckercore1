import { describe, it, expect } from 'vitest';
import handler from '../generate';

function createMockReqRes(method: string, body?: any) {
  const req: any = { method, body };
  let statusCode = 200;
  let jsonBody: any = null;
  const res: any = {
    status(code: number) { statusCode = code; return this; },
    json(payload: any) { jsonBody = payload; return this; },
    get _status() { return statusCode; },
    get _json() { return jsonBody; },
  };
  return { req, res };
}

describe('API /api/invoices/generate', () => {
  it('returns 201 and invoice on POST', async () => {
    const { req, res } = createMockReqRes('POST', {
      loadId: 'load_1',
      clientName: 'Shipper Inc',
      clientAddress: '123 Dock',
      origin: 'DAL',
      destination: 'AUS',
      miles: 200,
      ratePerMile: 2.25,
    });

    // @ts-expect-error - Next API types not required for unit test
    await handler(req, res);

    expect(res._status).toBe(201);
    expect(res._json).toHaveProperty('invoiceNumber');
    expect(res._json).toHaveProperty('total');
  });

  it('rejects non-POST methods', async () => {
    const { req, res } = createMockReqRes('GET');
    // @ts-expect-error - Next API types not required for unit test
    await handler(req, res);
    expect(res._status).toBe(405);
  });
});
