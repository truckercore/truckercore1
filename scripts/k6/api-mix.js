// scripts/k6/api-mix.js
import http from 'k6/http';
import { check, sleep } from 'k6';

export const options = {
  stages: [
    { duration: '2m', target: 50 },
    { duration: '5m', target: 200 },
    { duration: '2m', target: 0 },
  ],
  thresholds: {
    http_req_duration: ['p(95)<300'],
    http_req_failed: ['rate<0.01'],
  },
};

const BASE = __ENV.BASE_URL;
const KEY = __ENV.API_KEY;
const ORG = __ENV.ORG_ID;

export default function () {
  const headers = { 'X-Api-Key': KEY, 'X-Org-Id': ORG };
  // Read endpoints
  const r1 = http.get(`${BASE}/api/analytics/fleet?from=2025-01-01&to=2025-01-31`, { headers });
  check(r1, { '200 analytics fleet': (r) => r.status === 200 });

  const r2 = http.get(`${BASE}/api/hos/11111111-1111-1111-1111-111111111111?from=2025-01-01&to=2025-01-07`, { headers });
  check(r2, { '200 hos': (r) => r.status === 200 || r.status === 404 });

  // Occasional writes
  if (__ITER % 20 === 0) {
    const idem = `idem:${__VU}:${__ITER}`;
    const body = JSON.stringify({ category: 'fuel', amount_usd: 10, incurred_on: '2025-01-15' });
    const r3 = http.post(`${BASE}/api/ownerop/expenses`, body, { headers: { ...headers, 'Content-Type': 'application/json', 'Idempotency-Key': idem } });
    check(r3, { 'expenses write ok': (r) => r.status === 200 || r.status === 201 });
  }
  sleep(0.5);
}
