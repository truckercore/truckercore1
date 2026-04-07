#!/usr/bin/env node
/*
SQL Security Definer Hygiene Check
- Find functions declared with SECURITY DEFINER
- Assert they include: "set search_path" (explicit)
- Assert they do NOT contain dynamic SQL EXECUTE/format( unless whitelisted
- Assert GRANT EXECUTE is not given to PUBLIC (least-privilege)

Exit non-zero on violations; print file and line info best-effort.
*/

const fs = require('fs');
const path = require('path');

function listFiles(dir, ext = '.sql') {
  const out = [];
  const entries = fs.readdirSync(dir, { withFileTypes: true });
  for (const e of entries) {
    const p = path.join(dir, e.name);
    if (e.isDirectory()) out.push(...listFiles(p, ext));
    else if (e.isFile() && p.toLowerCase().endsWith(ext)) out.push(p);
  }
  return out;
}

function scanFile(file) {
  const txt = fs.readFileSync(file, 'utf8');
  const lc = txt.toLowerCase();
  const problems = [];

  // Split into function blocks roughly
  const reFn = /create\s+or\s+replace\s+function|create\s+function/gi;
  let match;
  while ((match = reFn.exec(lc)) !== null) {
    const start = match.index;
    const rest = lc.slice(start);
    const endIdx = rest.indexOf('$$;'); // naive terminator
    const block = endIdx > 0 ? txt.slice(start, start + endIdx + 3) : txt.slice(start);
    const blockLc = block.toLowerCase();
    if (!blockLc.includes('security definer')) continue; // only check definer

    // Requirement: set search_path explicitly
    if (!blockLc.includes('set search_path')) {
      problems.push({ file, rule: 'missing search_path', snippet: block.slice(0, 200) + '...' });
    }

    // Dynamic SQL check (forbid EXECUTE ... or format( ... ) unless whitelisted names)
    const allows = ['ensure_loads_partition', 'ensure_geofence_partition', 'weekly_geo_maintenance', 'prune_old_partitions', 'purge_billing_logs']; // allow benign dynamic DDL helpers
    const nameMatch = blockLc.match(/function\s+([a-z0-9_.]+)/);
    const fname = nameMatch ? nameMatch[1] : file;
    const hasDynamic = blockLc.includes(' execute ') || blockLc.includes('format(');
    if (hasDynamic && !allows.some(a => fname.endsWith(a))) {
      problems.push({ file, rule: 'dynamic sql in security definer', snippet: block.slice(0, 200) + '...' });
    }
  }

  // Least privilege: detect GRANT ... TO PUBLIC
  const reGrant = /grant\s+execute\s+on\s+function[^;]+to\s+public/gi;
  if (reGrant.test(lc)) {
    problems.push({ file, rule: 'grant execute to PUBLIC', snippet: txt.slice(0, 200) + '...' });
  }

  return problems;
}

function main() {
  const root = process.cwd();
  const sqlDirs = [path.join(root, 'supabase', 'migrations'), path.join(root, 'docs'), path.join(root, 'policies')].filter(fs.existsSync);
  let issues = [];
  for (const d of sqlDirs) {
    for (const f of listFiles(d, '.sql')) {
      try { issues.push(...scanFile(f)); } catch (e) { /* ignore parse errors */ }
    }
  }
  if (issues.length) {
    console.error('[sql-security-definer-check] Violations found:');
    for (const i of issues) {
      console.error(` - ${i.file}: ${i.rule}\n   ${i.snippet.replace(/\n/g,' ')}`);
    }
    process.exit(1);
  }
  console.log('[sql-security-definer-check] OK: no violations detected.');
}

main();
