import { ensureOrgScope } from '../api/lib/guard';
import { checkServiceRole } from '../api/lib/service_guard';

describe('authZ guards', () => {
  test('ensureOrgScope allows matching org and role', () => {
    const headers = {
      'x-app-org-id': 'org1',
      'x-app-roles': JSON.stringify(['dispatcher'])
    } as any;
    const res = ensureOrgScope(headers, 'org1', ['dispatcher']);
    expect((res as any).ok).toBe(true);
  });

  test('ensureOrgScope denies mismatched org', () => {
    const headers = { 'x-app-org-id': 'orgX', 'x-app-roles': '[]' } as any;
    const res = ensureOrgScope(headers, 'org1', []);
    expect((res as any).ok).toBe(false);
  });

  test('service_guard blocks service role in production by default', () => {
    const oldEnv = process.env.NODE_ENV;
    const oldKey = process.env.SUPABASE_SERVICE_ROLE_KEY;
    try {
      process.env.NODE_ENV = 'production';
      process.env.SUPABASE_SERVICE_ROLE_KEY = 'SVC-KEY-123';
      const headers = { authorization: 'Bearer SVC-KEY-123' } as any;
      const res = checkServiceRole(headers);
      expect(res.ok).toBe(false);
    } finally {
      if (oldEnv === undefined) delete (process.env as any).NODE_ENV; else process.env.NODE_ENV = oldEnv;
      if (oldKey === undefined) delete (process.env as any).SUPABASE_SERVICE_ROLE_KEY; else process.env.SUPABASE_SERVICE_ROLE_KEY = oldKey;
    }
  });

  test('service_guard allows when explicitly permitted', () => {
    const oldEnv = process.env.NODE_ENV;
    const oldKey = process.env.SUPABASE_SERVICE_ROLE_KEY;
    try {
      process.env.NODE_ENV = 'production';
      process.env.SUPABASE_SERVICE_ROLE_KEY = 'SVC-KEY-123';
      const headers = { authorization: 'Bearer SVC-KEY-123' } as any;
      const res = checkServiceRole(headers, { allowInProd: true });
      expect(res.ok).toBe(true);
    } finally {
      if (oldEnv === undefined) delete (process.env as any).NODE_ENV; else process.env.NODE_ENV = oldEnv;
      if (oldKey === undefined) delete (process.env as any).SUPABASE_SERVICE_ROLE_KEY; else process.env.SUPABASE_SERVICE_ROLE_KEY = oldKey;
    }
  });
});
