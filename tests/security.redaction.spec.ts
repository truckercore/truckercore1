// tests/security.redaction.spec.ts
import { withRedactedLogger } from '../security/redaction-middleware';

describe('Log redaction middleware', () => {
  it('redacts secrets in headers/body/meta', () => {
    const captured: any[] = [];
    const logger = { info: (_m: any, meta?: any) => captured.push({ level: 'info', meta }), warn: () => {}, error: () => {} } as any;

    const req: any = {
      method: 'POST',
      path: '/v1/test',
      headers: { 'x-api-key': 'abcd1234abcd1234abcd1234abcd1234', authorization: 'Bearer eyJhbGciOiJIUzI1NiIsInR5cCI...' },
      query: {},
      body: { token: 'shh-very-secret', nested: { password: 'P@ssw0rd!' }, note: 'apiKey=ABC123SECRET' }
    };
    const res: any = {};
    const next = () => {};

    const mw = withRedactedLogger(logger);
    mw(req as any, res as any, next as any);

    (req as any).log.info('processing', { api_key: 'ZXY-VERY-SECRET', nested: { secret: 'dont-log-this' }, jwt: 'eyJhbGciOiJIUzI1NiIsInR5cCI...' });

    const last = captured[captured.length - 1];
    const s = JSON.stringify(last);
    expect(s).not.toMatch(/abcd1234abcd1234/);
    expect(s).not.toMatch(/shh-very-secret/);
    expect(s).not.toMatch(/P@ssw0rd!/);
    expect(s).not.toMatch(/ZXY-VERY-SECRET/);
    expect(s).not.toMatch(/eyJhbGciOiJI/);
    expect(s).not.toMatch(/apiKey=ABC123SECRET/);
    expect(s).toMatch(/\*\*\*\*REDACTED\*\*\*\*/);
  });
});
