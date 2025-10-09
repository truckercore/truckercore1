// cli/load/k6_user_profile.js
// Quick k6 load test for user-profile endpoint
// Usage:
//   k6 run -e BASE=https://<PROJECT>.supabase.co/functions/v1/user-profile -e USER_JWT=<jwt> cli/load/k6_user_profile.js

import http from 'k6/http';
import { sleep, check } from 'k6';

export const options = { vus: 20, duration: '2m' };
const BASE = __ENV.BASE;
const TOKEN = __ENV.USER_JWT;

export default function () {
  const res = http.get(BASE, { headers: { Authorization: `Bearer ${TOKEN}` } });
  check(res, { 'status 200': (r) => r.status === 200 });
  sleep(0.2);
}
