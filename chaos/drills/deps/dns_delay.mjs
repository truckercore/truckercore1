#!/usr/bin/env node
// Dependency Chaos: DNS delay/failure (Dry-run by default)

const CHAOS_ENABLED = String(process.env.CHAOS_ENABLED || 'false').toLowerCase() === 'true';
const ENV = process.env.ENV || 'staging';

function log(step, data={}) { console.log(JSON.stringify({ drill: 'deps_dns_delay', step, env: ENV, dry_run: !CHAOS_ENABLED, ...data })); }

(async () => {
  log('start');
  log('plan', { actions: ['inject DNS resolution delay/failures for webhook hosts', 'assert SSRF guard behavior', 'validate retries/backoff'] });
  if (!CHAOS_ENABLED) { log('dry_run_notice'); return; }
  log('inject_dns_delay', { status: 'skipped_in_stub' });
  log('assert_ssrf_guard', { status: 'skipped_in_stub' });
  log('validate_retries', { status: 'skipped_in_stub' });
  log('done');
})();
