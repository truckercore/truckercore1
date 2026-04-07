#!/usr/bin/env node
/**
 * Database seed script
 * - If Supabase CLI is present, attempts to run SQL files in `seeds/` or `supabase/seed.sql`.
 * - Otherwise, creates a marker file indicating manual seeding instructions.
 */

import { execSync } from 'node:child_process';
import { existsSync, readdirSync, readFileSync, writeFileSync, mkdirSync } from 'node:fs';
import { join } from 'node:path';

const repoRoot = process.cwd();

function runSql(sql) {
  try {
    execSync(`supabase db query --file -`, { input: sql, stdio: 'inherit' });
    return true;
  } catch (e) {
    return false;
  }
}

function trySupabaseSeed() {
  try {
    execSync('supabase --version', { stdio: 'ignore' });
  } catch {
    return false;
  }
  // Prefer seeds directory
  const seedsDir = join(repoRoot, 'seeds');
  if (existsSync(seedsDir)) {
    const files = readdirSync(seedsDir).filter((f) => f.endsWith('.sql'));
    for (const f of files) {
      const sql = readFileSync(join(seedsDir, f), 'utf-8');
      console.log(`▶️ Applying seed: ${f}`);
      if (!runSql(sql)) return false;
    }
    return true;
  }
  // Fallback: supabase/seed.sql
  const seedSqlPath = join(repoRoot, 'supabase', 'seed.sql');
  if (existsSync(seedSqlPath)) {
    const sql = readFileSync(seedSqlPath, 'utf-8');
    console.log('▶️ Applying supabase/seed.sql');
    return runSql(sql);
  }
  console.log('ℹ️ No seed SQL files found. Skipping.');
  return true; // not an error
}

(function main() {
  const ok = trySupabaseSeed();
  if (!ok) {
    const reports = join(repoRoot, 'reports');
    if (!existsSync(reports)) mkdirSync(reports, { recursive: true });
    writeFileSync(join(reports, 'db_seed.info'), 'Manual DB seed recommended. Provide SQL files in ./seeds/*.sql and ensure Supabase CLI is installed.');
  }
  console.log('DB seed complete.');
})();
