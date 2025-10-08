#!/usr/bin/env node
import fs from 'fs';
import path from 'path';

/**
 * Count affected records by operation type from one or many DLQ export files.
 * Usage:
 *   node scripts/dlq/count-by-operation.mjs dlq_backup_*.json
 */

const files = process.argv.slice(2);
if (files.length === 0) {
  console.error('Usage: node scripts/dlq/count-by-operation.mjs <files...>');
  process.exit(1);
}

const counts = {};
let total = 0;

for (const pattern of files) {
  // Basic glob: support simple wildcard * at end or use direct file
  const dir = path.dirname(pattern);
  const base = path.basename(pattern);
  let list = [];
  if (base.includes('*')) {
    const [prefix, suffix] = base.split('*');
    list = fs.readdirSync(dir === '.' ? process.cwd() : dir)
      .filter((f) => f.startsWith(prefix) && f.endsWith(suffix || ''))
      .map((f) => path.join(dir, f));
  } else {
    list = [pattern];
  }

  for (const file of list) {
    try {
      const raw = fs.readFileSync(file, 'utf8');
      const arr = JSON.parse(raw);
      if (!Array.isArray(arr)) continue;
      for (const item of arr) {
        const op = item?.operation || item?.payload?.operation || 'unknown';
        counts[op] = (counts[op] || 0) + 1;
        total++;
      }
    } catch (e) {
      console.error(`Skipping ${file}: ${e.message}`);
    }
  }
}

// Print sorted counts (desc)
const sorted = Object.entries(counts).sort((a, b) => b[1] - a[1]);
for (const [op, cnt] of sorted) {
  console.log(`${String(cnt).padStart(6, ' ')}  ${op}`);
}
console.log(`Total: ${total}`);
