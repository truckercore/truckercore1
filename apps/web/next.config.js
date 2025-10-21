// Proxy to the root Next.js configuration so Vercel (and local builds) work from the apps/web directory.
// This allows monorepo builds that execute within apps/web to pick up shared settings.
const path = require('path');

// Resolve the root next.config.js relative to this file
const rootNextConfigPath = path.resolve(__dirname, '..', '..', 'next.config.js');

// eslint-disable-next-line import/no-dynamic-require, global-require
const rootConfig = require(rootNextConfigPath);

module.exports = rootConfig;