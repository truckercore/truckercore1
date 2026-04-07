import http from 'k6/http';
import { sleep } from 'k6';

export const options = {
  vus: __ENV.VUS ? parseInt(__ENV.VUS) : 50,
  duration: __ENV.DURATION || '30s',
  thresholds: {
    http_req_duration: ['p(95)<500'], // CI gate default
  },
};

export default function () {
  const res = http.get(__ENV.TARGET_URL);
  if (res.status >= 500) {
    // Count server errors (k6 will track)
  }
  sleep(0.1);
}
