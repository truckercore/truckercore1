import http from 'k6/http';
import { check, sleep } from 'k6';

export const options = {
  vus: 20,
  duration: '2m',
  thresholds: {
    http_req_duration: ['p(95)<800'],
  },
};

export default function () {
  const res = http.get(`${__ENV.FUNC_URL}/health`);
  check(res, { 'status 200': (r) => r.status === 200 });
  sleep(1);
}
