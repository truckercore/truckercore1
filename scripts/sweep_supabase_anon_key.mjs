#!/usr/bin/env node
// scripts/sweep_supabase_anon_key.mjs
// Prints files containing SUPABASE_ANON_KEY outside the allowlist. Mirrors CI/pre-commit rules.

import { execSync } from 'node:child_process';

const ALLOW = new RegExp('(^docs/|^README|^.*\\.md$|^.*\\.env(\\.example|\\.local|\\.template)?$|^apps/web/README\\.md$|^ALLOW_SUPABASE_ANON_KEY_REFERENCES\\.txt$)');

function main(){
  let matched = '';
  try {
    matched = execSync('git grep -n "SUPABASE_ANON_KEY" -- .', { stdio: ['ignore', 'pipe', 'ignore'] }).toString();
  } catch (e) {
    // git grep exits non-zero if no matches; treat as no matches
    matched = '';
  }
  if (!matched.trim()){
    console.log('[sweep] No references found.');
    return;
  }
  const lines = matched.trim().split(/\r?\n/);
  const disallowed = [];
  for (const line of lines){
    const [file, lineNum, rest] = line.split(':');
    if (!ALLOW.test(file)){
      disallowed.push(`${file}:${lineNum}:${rest}`);
    }
  }
  if (disallowed.length){
    console.log('[sweep] Disallowed SUPABASE_ANON_KEY references found:');
    for (const d of disallowed) console.log(d);
    process.exitCode = 1;
  } else {
    console.log('[sweep] Only allowed references found.');
  }
}

main();
