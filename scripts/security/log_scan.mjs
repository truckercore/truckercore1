// scripts/security/log_scan.mjs
// Simple grep-like scanner for sensitive tokens in provided files or stdio (future).
// Usage: npm run scan:logs -- path1 path2 ...
import fs from 'fs';

const files = process.argv.slice(2);
if (files.length === 0) {
  console.log('[scan:logs] No files provided. Usage: npm run scan:logs -- file1.log file2.log');
  process.exit(0);
}

const PATTERNS = [
  /(api[_-]?key|secret|password)\s*=\s*[^\s&]+/i,
  /\b[a-f0-9]{32,64}\b/g, // hex tokens
  /Bearer\s+[A-Za-z0-9-_]{20,}\.[A-Za-z0-9-_]{10,}\.[A-Za-z0-9-_]{10,}/, // JWT-like
];

let found = 0;
for (const f of files) {
  try {
    const text = fs.readFileSync(f, 'utf8');
    for (const re of PATTERNS) {
      const m = text.match(re);
      if (m && m.length) {
        console.error(`[scan:logs] Potential secret in ${f}:`, String(re));
        found += m.length;
      }
    }
  } catch (e) {
    console.error(`[scan:logs] Failed to read ${f}:`, e.message);
  }
}

if (found > 0) {
  console.error(`[scan:logs] Found ${found} potential secret occurrences.`);
  process.exit(2);
} else {
  console.log('[scan:logs] No secrets detected.');
}
