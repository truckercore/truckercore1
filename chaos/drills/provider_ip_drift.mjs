#!/usr/bin/env node
// Chaos Drill: Provider IP Drift (Dry-run by default)

const CHAOS_ENABLED = String(process.env.CHAOS_ENABLED || 'false').toLowerCase() === 'true';
const ENV = process.env.ENV || 'staging';
const WEBHOOK_PROVIDER = process.env.WEBHOOK_PROVIDER || 'custom';

function log(step, data={}) { console.log(JSON.stringify({ drill: 'provider_ip_drift', step, env: ENV, provider: WEBHOOK_PROVIDER, dry_run: !CHAOS_ENABLED, ...data })); }

(async () => {
  log('start');
  log('plan', { actions: ['simulate webhook from unknown IP', 'observe allowlist decision', 'validate audit log'] });

  if (!CHAOS_ENABLED) {
    log('dry_run_notice');
    return;
  }

  log('simulate_unknown_ip', { status: 'skipped_in_stub' });
  log('observe_allowlist', { status: 'skipped_in_stub' });
  log('validate_logging', { status: 'skipped_in_stub' });
  log('done');
})();
