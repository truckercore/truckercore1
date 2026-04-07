import http from 'k6/http';
import { check, sleep } from 'k6';
export const options = {
  thresholds: {
    http_req_failed: ['rate<0.01'],
    http_req_duration: ['p(95)<800'],
  },
  vus: 5,
  duration: '1m',
};
const BASE = __ENV.BASE || 'http://127.0.0.1:54321';

export default function () {
  const r = http.get(`${BASE}/rest/v1/health`);
  check(r, { '200': (res) => res.status === 200 });
  sleep(1);
}
