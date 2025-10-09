#!/usr/bin/env node
// Wrapper to run the existing demo seeder using the expected filename
(async () => {
  try {
    await import('./seed_demo_data.mjs');
  } catch (e) {
    console.error('[seed-demo-data] Failed to run seed_demo_data.mjs:', e);
    process.exit(1);
  }
})();
