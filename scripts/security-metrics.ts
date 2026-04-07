// Shim entry to match expected path in verification checklist.
// Delegates to the existing implementation at scripts/security/security-metrics.ts

import('./security/security-metrics').catch((e) => {
  // Fallback: attempt to require CommonJS if transpiled differently
  try {
    // eslint-disable-next-line @typescript-eslint/no-var-requires
    require('./security/security-metrics');
  } catch (err) {
    // eslint-disable-next-line no-console
    console.error('Failed to execute security metrics script:', e || err);
    process.exit(1);
  }
});
