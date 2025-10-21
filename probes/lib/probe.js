// probes/lib/probe.js
export const EXIT = { PASS: 0, DEGRADED: 10, FAIL: 20, INFRA: 30 };

export function nowIso() {
  return new Date().toISOString();
}

export function printProbe({
  probe, status, tenant, latency_ms = 0, details = {}, evidence = {}
}) {
  const line = {
    probe, status, ts: nowIso(), tenant, latency_ms, details, evidence
  };
  process.stdout.write(JSON.stringify(line) + "\n");
}

export function exitFor(status) {
  if (status === 'pass') return EXIT.PASS;
  if (status === 'degraded') return EXIT.DEGRADED;
  if (status === 'fail') return EXIT.FAIL;
  return EXIT.INFRA;
}
