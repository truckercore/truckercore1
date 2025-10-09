import { logEvent } from '../api/lib/logging';

describe('logging redaction', () => {
  test('redacts sensitive keys and patterns before sink', () => {
    const outputs: any[] = [];
    const orig = console.log;
    // Capture console output
    // @ts-ignore
    console.log = (msg: string) => { try { outputs.push(JSON.parse(msg)); } catch { outputs.push(msg); } };

    const jwt = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJhIjoiYiJ9.sgnatureLikeString';
    const longNumber = '1234567890123456';

    const cid = logEvent('info', 'test', {
      org_id: 'o1',
      user_id: 'u1',
      correlation_id: 'cid-123',
      authorization: 'Bearer abcdef123456',
      password: 'supersecret',
      token: 'tkn-xyz',
      jwt,
      note: `User presented JWT ${jwt} and number ${longNumber}`,
      nested: { client_secret: 'shhh', email: 'user@example.com' }
    });

    // Restore
    console.log = orig;

    expect(typeof cid).toBe('string');
    const last = outputs.pop();
    expect(last.level).toBe('info');
    expect(last.org_id).toBe('o1');
    expect(last.correlation_id).toBe('cid-123');
    const dumped = JSON.stringify(last);
    expect(dumped).not.toMatch(/supersecret/i);
    expect(dumped).not.toMatch(/Bearer\s+abcdef123456/i);
    expect(dumped).not.toMatch(/tkn-xyz/i);
    expect(dumped).not.toMatch(/client_secret":"shhh/i);
    expect(dumped).not.toMatch(/user@example.com/i);
    expect(dumped).not.toMatch(/eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9/); // JWT masked
    expect(dumped).not.toMatch(/1234567890123456/); // long number masked
    expect(dumped).toMatch(/\[REDACTED\]/);
    expect(dumped).toMatch(/\[REDACTED_EMAIL\]/);
    expect(dumped).toMatch(/\[REDACTED_JWT\]/);
    expect(dumped).toMatch(/\[REDACTED_NUM\]/);
  });
});
