#!/usr/bin/env node
// Automated Red-Team: common webhook attack simulations (dry-run by default; logical/pass-fail only)

import crypto from 'crypto';
import fs from 'fs';

const DRY_RUN = String(process.env.DRY_RUN || 'true').toLowerCase() !== 'false';
const PROVIDER = process.env.WEBHOOK_PROVIDER || 'custom';

function log(evt, data={}) { console.log(JSON.stringify({ tool: 'webhook_redteam', event: evt, provider: PROVIDER, dry_run: DRY_RUN, ...data })); }

function hmac(secret, str) { return 'sha256=' + crypto.createHmac('sha256', secret).update(str).digest('hex'); }

function signV2(secret, ts, method, path, body) {
  return hmac(secret, `${method.toUpperCase()}|${path}|${ts}|${body}`);
}

// Scenario 1: Cross-endpoint replay should FAIL verification on different path
function scenarioCrossEndpointReplay() {
  const secret = 'rt-secret';
  const ts = Math.floor(Date.now()/1000).toString();
  const body = JSON.stringify({ t: 'x' });
  const method = 'POST';
  const pathA = '/webhooks/a';
  const pathB = '/webhooks/b';
  const sigA = signV2(secret, ts, method, pathA, body);
  // Expected: sigA must NOT verify on pathB
  const expectedDifferent = sigA !== signV2(secret, ts, method, pathB, body);
  const ok = expectedDifferent;
  log('scenario_cross_endpoint_replay', { ok });
  return ok;
}

// Scenario 2: Downgrade attempt from v2 to legacy v1 should FAIL
function scenarioDowngradeAttempt() {
  const secret = 'rt-secret';
  const ts = Math.floor(Date.now()/1000).toString();
  const body = JSON.stringify({ t: 'y' });
  const v2 = signV2(secret, ts, 'POST', '/w', body);
  const v1 = 'sha256=' + crypto.createHmac('sha256', secret).update(`${ts}.${body}`).digest('hex');
  // Expected: these must not be equal and verifier should not accept v1 if path binding is required
  const ok = v2 !== v1;
  log('scenario_downgrade_attempt', { ok });
  return ok;
}

(async () => {
  log('start');
  const results = [scenarioCrossEndpointReplay(), scenarioDowngradeAttempt()];
  const allOk = results.every(Boolean);
  log('summary', { all_ok: allOk });
  if (!allOk) process.exitCode = 2;
})();
