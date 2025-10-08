#!/usr/bin/env node
/**
 * Checks for required homepage assets in apps/web/public
 */
import { existsSync, statSync } from 'fs';
import { fileURLToPath } from 'url';
import { dirname, join } from 'path';

const __filename = fileURLToPath(import.meta.url);
const __dirname = dirname(__filename);
const publicDir = join(__dirname, '..', 'apps', 'web', 'public');

const requiredAssets = [
  { file: 'favicon.ico', size: '32x32 ICO', required: true },
  { file: 'og-image.png', size: '1200x630 PNG', required: true },
  { file: 'apple-touch-icon.png', size: '180x180 PNG', required: true },
  { file: 'icon-192.png', size: '192x192 PNG', required: true },
  { file: 'icon-512.png', size: '512x512 PNG', required: true },
];

console.log('Checking homepage assets in', publicDir, '...\n');
let missing = 0;
let warnings = 0;

for (const { file, size, required } of requiredAssets) {
  const path = join(publicDir, file);
  const exists = existsSync(path);
  if (exists) {
    try {
      const stats = statSync(path);
      const kb = (stats.size / 1024).toFixed(1);
      console.log(`✓ ${file} (${kb}KB)`);
    } catch {
      console.log(`✓ ${file}`);
    }
  } else {
    // Allow favicon.png as fallback if favicon.ico missing
    if (file === 'favicon.ico') {
      const pngFallback = existsSync(join(publicDir, 'favicon.png'));
      if (pngFallback) {
        console.log(`⚠ ${file} (${size}) - missing, but favicon.png found (convert to .ico for production)`);
        warnings++;
        continue;
      }
    }
    if (required) {
      console.log(`✗ ${file} (${size}) - MISSING (required)`);
      missing++;
    } else {
      console.log(`⚠ ${file} (${size}) - missing (optional)`);
      warnings++;
    }
  }
}

console.log('\n' + '='.repeat(50));
if (missing > 0) {
  console.log(`❌ ${missing} required asset(s) missing`);
  console.log('\nRun: npm run generate:assets');
  console.log('Or see: docs/homepage/ASSET_GUIDE.md');
  process.exit(1);
} else if (warnings > 0) {
  console.log(`⚠️  All required assets present, ${warnings} optional/fallback warnings`);
  process.exit(0);
} else {
  console.log('✅ All assets present');
  process.exit(0);
}
