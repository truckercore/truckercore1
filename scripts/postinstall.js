#!/usr/bin/env node
const { execSync } = require('child_process');

// When running on Vercel, the VERCEL env var is set to "1". Skip electron native rebuilds there.
if (process.env.VERCEL) {
  console.log('VERCEL detected, skipping electron postinstall.');
  process.exit(0);
}

try {
  console.log('Running electron-builder install-app-deps...');
  execSync('electron-builder install-app-deps', { stdio: 'inherit' });
} catch (err) {
  console.error('electron postinstall failed:', err);
  process.exit(1);
}
