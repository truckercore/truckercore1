// probes/rate_limit.mjs
import { printProbe, exitFor } from './lib/probe.js';

const start = Date.now();
let status = 'pass'; let details = {}; let evidence = {};
try {
  const endpoint = process.env.RL_ENDPOINT;
  if (!endpoint) {
    status = 'degraded'; details = { hint: 'missing_env', required: ['RL_ENDPOINT'] };
  } else {
    let got429 = false;
    for (let i = 0; i < 10; i++) {
      const res = await fetch(endpoint, { method: 'POST' });
      if (res.status === 429) got429 = true;
    }
    if (!got429) { status = 'fail'; details = { hint: 'no_429' }; }
  }
} catch (e) {
  status = 'fail'; details = { hint: String(e?.message||e) };
} finally {
  const latency_ms = Date.now() - start;
  printProbe({ probe: 'rate_limit', status, tenant: 'global', latency_ms, details, evidence });
  process.exit(exitFor(status));
}
