// Scan docs/sql for SECURITY DEFINER functions missing set_config(search_path)
import fs from 'node:fs';
import path from 'node:path';

const root = path.resolve(process.cwd(), 'docs', 'sql');
let failed = false;

function scanFile(fp) {
  const s = fs.readFileSync(fp, 'utf8');
  const lower = s.toLowerCase();
  const idx = lower.indexOf('security definer');
  if (idx === -1) return; // no SD
  // Inspect block from 'security definer' to next $$ terminator
  const after = s.slice(idx);
  const endIdx = after.indexOf('$$');
  const block = endIdx === -1 ? after : after.slice(0, endIdx);
  if (!/set_config\s*\(\s*'search_path'/i.test(block)) {
    console.error(`::error file=${fp}::SECURITY DEFINER function missing set_config(search_path)`);
    failed = true;
  }
}

function walk(dir) {
  for (const entry of fs.readdirSync(dir, { withFileTypes: true })) {
    const fp = path.join(dir, entry.name);
    if (entry.isDirectory()) walk(fp);
    else if (entry.isFile() && fp.endsWith('.sql')) scanFile(fp);
  }
}

if (fs.existsSync(root)) walk(root);
if (failed) { process.exit(1); }
console.log('[ok] migration-security');
