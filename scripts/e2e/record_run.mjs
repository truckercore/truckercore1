#!/usr/bin/env node
// scripts/e2e/record_run.mjs
// Usage: node scripts/e2e/record_run.mjs --suite playwright --project chromium --env ci --status passed --specs 12 --failed 0 --duration 123456 --artifact https://...
// Requires: SUPABASE_URL, SUPABASE_SERVICE_ROLE

import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';

function arg(name, def = undefined) {
  const i = process.argv.indexOf(`--${name}`);
  return i > -1 ? process.argv[i + 1] : def;
}

const url = process.env.SUPABASE_URL;
const key = process.env.SUPABASE_SERVICE_ROLE || process.env.SUPABASE_SERVICE_ROLE_KEY;
if (!url || !key) {
  console.error('[record_run] Missing SUPABASE_URL or SUPABASE_SERVICE_ROLE');
  process.exit(2);
}

const suite = arg('suite', process.env.E2E_SUITE || 'playwright');
const project = arg('project', process.env.E2E_PROJECT || 'chromium');
const env = arg('env', process.env.E2E_ENV || 'ci');
const status = arg('status', process.env.E2E_STATUS || 'passed');
const specs_total = Number(arg('specs', process.env.E2E_SPECS || '0'));
const specs_failed = Number(arg('failed', process.env.E2E_FAILED || '0'));
const duration_ms = Math.round(Number(arg('duration', process.env.E2E_DURATION || '0')));
const artifact_url = arg('artifact', process.env.E2E_ARTIFACT || null);

const db = createClient(url, key, { auth: { persistSession: false } });
const { error } = await db.from('e2e_runs').insert([{
  suite, project, env, status,
  specs_total, specs_failed, duration_ms,
  artifact_url
}]);
if (error) {
  console.error('[record_run] insert failed:', error.message);
  process.exit(1);
}
console.log('[record_run] recorded', suite, project, status, duration_ms + 'ms');
