#!/usr/bin/env node
/**
 * Database setup script
 * - If Supabase CLI is available and supabase/config exists, attempt to run `supabase db reset`.
 * - Otherwise, create a marker file and log instructions for manual setup.
 */

import { execSync } from 'node:child_process';
import { existsSync, mkdirSync, writeFileSync } from 'node:fs';
import { join } from 'node:path';

const repoRoot = process.cwd();

function hasSupabaseProject() {
  return existsSync(join(repoRoot, 'supabase')) && existsSync(join(repoRoot, 'supabase', 'migrations'));
}

function trySupabaseReset() {
  try {
    execSync('supabase --version', { stdio: 'ignore' });
    console.log('🔧 Supabase CLI detected. Running `supabase db reset`...');
    execSync('supabase db reset --debug', { stdio: 'inherit' });
    console.log('✅ Database reset complete.');
    return true;
  } catch (e) {
    console.warn('⚠️ Supabase CLI not available or reset failed. Skipping automatic reset.');
    return false;
  }
}

(async function main() {
  if (hasSupabaseProject()) {
    const ok = trySupabaseReset();
    if (!ok) {
      // Create setup marker and exit gracefully
      const dir = join(repoRoot, 'reports');
      if (!existsSync(dir)) mkdirSync(dir, { recursive: true });
      writeFileSync(join(dir, 'db_setup.info'), 'Manual DB setup required. Install Supabase CLI and run: supabase db reset');
    }
  } else {
    console.log('ℹ️ No supabase project found. Skipping DB reset.');
  }
  console.log('DB setup complete.');
})();
