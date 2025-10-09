// probes/sso_canary.mjs
import assert from "node:assert/strict";

const start = Date.now();
let status = "pass";
let details = {};
let tenant = null;

try {
  const url = process.env.SSO_CANARY_URL;
  if (!url) {
    status = 'degraded';
    details = { hint: 'missing_env', required: ['SSO_CANARY_URL'] };
  } else {
    const r = await fetch(url, { method: "POST" });
    assert.equal(r.status, 200);
    const j = await r.json();
    details = { idp: j.idp, tenant: j.tenant };
    tenant = j.tenant ?? null;
  }
} catch (e) {
  status = "fail";
  details = { error: String(e) };
}

const latency_ms = Date.now() - start;
console.log(JSON.stringify({
  probe: "sso_canary",
  status,
  ts: new Date().toISOString(),
  tenant,
  latency_ms,
  details
}));
process.exit(status === "pass" ? 0 : status === 'degraded' ? 10 : 20);
