import request from 'supertest';
import { makeTestApp } from './app';

export function req() {
  const app = makeTestApp();
  return request(app);
}

export function headersFor(scopes: string[], orgId?: string) {
  const h: Record<string, string> = {
    Authorization: 'Bearer test-token',
    'X-Scopes': scopes.join(' '),
  };
  if (orgId) h['X-Org-Id'] = orgId;
  return h;
}
