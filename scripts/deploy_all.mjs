#!/usr/bin/env node
// scripts/deploy_all.mjs
// Cross-platform helper to deploy all Supabase Edge Functions in this repo.
// Prerequisites:
//   - Supabase CLI installed and authenticated (supabase login)
// Usage:
//   node scripts/deploy_all.mjs
// Options:
//   --skip-build  Skip verification/bundle checks (passes --no-verify)

import { spawn } from 'node:child_process';

const FUNCTIONS = [
  'ai_matchmaker',
  'org_job_worker',
  'org_queue_worker',
  'admin_diagnostics',
  'synthetic_load',
  'metrics_push',
  'stripe_webhooks',
];

function run(cmd, args, opts = {}) {
  return new Promise((resolve, reject) => {
    const child = spawn(cmd, args, { stdio: 'inherit', shell: process.platform === 'win32', ...opts });
    child.on('exit', (code) => {
      if (code === 0) resolve();
      else reject(new Error(`${cmd} ${args.join(' ')} -> exit ${code}`));
    });
    child.on('error', reject);
  });
}

async function main() {
  const skip = process.argv.includes('--skip-build');
  console.log(`[deploy_all] Deploying ${FUNCTIONS.length} functions...`);
  for (const fn of FUNCTIONS) {
    const args = ['functions', 'deploy', fn];
    if (skip) args.push('--no-verify');
    console.log('[deploy_all] supabase ' + args.join(' '));
    await run('supabase', args);
    console.log(`[deploy_all] OK -> ${fn}`);
  }
  console.log('[deploy_all] Done.');
}

main().catch((e) => {
  console.error('[deploy_all] FAILED:', e.message || e);
  process.exit(1);
});
