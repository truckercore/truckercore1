#!/usr/bin/env node
// scripts/deploy_supabase_schemas.mjs
// Cross-platform helper to deploy all Supabase schemas for this repository.
// - Applies migrations in supabase/migrations via `supabase db push`
// - Applies standalone SQL files in docs/supabase via `supabase db query -f <file.sql>` in sorted order
//
// Prerequisites:
//   - Supabase CLI installed and authenticated (supabase login)
//   - Project linked or provide flags as needed (CLI will prompt)
//
// Usage:
//   node scripts/deploy_supabase_schemas.mjs
//   node scripts/deploy_supabase_schemas.mjs --skip-migrations

import { spawn } from 'node:child_process';
import { readdirSync } from 'node:fs';
import { resolve, join } from 'node:path';

const ROOT = resolve(process.cwd());
const DOCS_SQL_DIR = resolve(join(ROOT, 'docs', 'supabase'));

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

async function applyMigrations(skip) {
  if (skip) {
    console.log('[deploy_schemas] Skipping migrations (per flag).');
    return;
  }
  console.log("[deploy_schemas] Applying migrations via 'supabase db push'...");
  await run('supabase', ['db', 'push']);
  console.log('[deploy_schemas] Migrations applied.');
}

function listDocsSql() {
  try {
    const files = readdirSync(DOCS_SQL_DIR, { withFileTypes: true })
      .filter((d) => d.isFile() && d.name.toLowerCase().endsWith('.sql'))
      .map((d) => d.name)
      .sort((a, b) => a.localeCompare(b));
    return files.map((name) => resolve(join(DOCS_SQL_DIR, name)));
  } catch (e) {
    return [];
  }
}

async function applyDocsSql() {
  const files = listDocsSql();
  if (files.length === 0) {
    console.log('[deploy_schemas] No *.sql files found under docs/supabase.');
    return;
  }
  console.log(`[deploy_schemas] Applying ${files.length} SQL file(s) from docs/supabase...`);
  for (const f of files) {
    console.log('[deploy_schemas] Applying:', f);
    await run('supabase', ['db', 'query', '-f', f]);
  }
  console.log('[deploy_schemas] docs/supabase SQL applied.');
}

async function main() {
  const skip = process.argv.includes('--skip-migrations');
  await applyMigrations(skip);
  await applyDocsSql();
  console.log('[deploy_schemas] Done.');
}

main().catch((e) => {
  console.error('[deploy_schemas] FAILED:', e?.message || e);
  process.exit(1);
});
