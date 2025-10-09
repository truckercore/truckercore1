#!/usr/bin/env node
/*
 Simple runbooks validator:
 - Ensure runbooks/ exists
 - Each *.md has an H1 title
 - Must include key sections: Summary, Monitoring, Rollback (case-insensitive)
 - Fail with non-zero exit if any violations
*/

const fs = require('fs');
const path = require('path');

const ROOT = process.cwd();
const RUNBOOKS_DIR = path.join(ROOT, 'runbooks');

function listMarkdown(dir) {
  if (!fs.existsSync(dir)) return [];
  const entries = fs.readdirSync(dir, { withFileTypes: true });
  const files = [];
  for (const e of entries) {
    const p = path.join(dir, e.name);
    if (e.isDirectory()) files.push(...listMarkdown(p));
    else if (e.isFile() && e.name.toLowerCase().endsWith('.md')) files.push(p);
  }
  return files;
}

function validateFile(file) {
  const text = fs.readFileSync(file, 'utf8');
  const lines = text.split(/\r?\n/);
  const title = lines.find(l => /^#\s+/.test(l));
  const lc = text.toLowerCase();
  const req = ['summary', 'monitoring', 'rollback'];
  const missing = [];
  if (!title) missing.push('H1 title');
  for (const k of req) {
    if (!lc.includes(`## ${k}`) && !lc.includes(`### ${k}`)) {
      missing.push(k);
    }
  }
  return missing;
}

function main() {
  let failed = false;
  if (!fs.existsSync(RUNBOOKS_DIR)) {
    console.log('[runbooks] runbooks/ directory not found; skipping (pass).');
    return;
  }
  const files = listMarkdown(RUNBOOKS_DIR);
  if (files.length === 0) {
    console.log('[runbooks] No markdown files found in runbooks/; skipping (pass).');
    return;
  }
  const results = [];
  for (const f of files) {
    const missing = validateFile(f);
    if (missing.length > 0) {
      failed = true;
      results.push({ file: path.relative(ROOT, f), missing });
    }
  }
  if (failed) {
    console.error('[runbooks] Validation failed for the following files:');
    for (const r of results) {
      console.error(` - ${r.file}: missing ${r.missing.join(', ')}`);
    }
    process.exit(1);
  } else {
    console.log(`[runbooks] All ${files.length} runbook(s) look good.`);
  }
}

main();
