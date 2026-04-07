// probes/templates/scaffold.mjs
import { printProbe, exitFor } from '../lib/probe.js';

const start = Date.now();
let status = 'pass';
let details = {};
let evidence = {};

try {
  // ... run probe logic ...

  // example evidence
  details = { hint: 'ok' };
  evidence = { ids: [], hash: 'sha256:...' };

} catch (e) {
  status = 'fail';
  details = { hint: String(e?.message || e) };
} finally {
  const latency_ms = Date.now() - start;
  printProbe({
    probe: 'tenant_health', status, tenant: process.env.PROBE_TENANT || 'unknown',
    latency_ms, details, evidence
  });
  process.exit(exitFor(status));
}
