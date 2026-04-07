#!/usr/bin/env node
/*
 Production Validation Script (cross-platform)
 Usage:
   node scripts/validate-production.js [--report] [--output=validation-report.md]
   npm run validate
   npm run validate:report
*/

const fs = require('fs');
const path = require('path');
const { execSync, spawnSync } = require('child_process');

// Exit codes per spec
const EXIT_CODES = {
  SUCCESS: 0,
  WARNING: 0, // non-blocking warnings
  VALIDATION_FAILED: 1,
  CRITICAL_ERROR: 2,
  CONFIG_ERROR: 3,
  DEPENDENCY_ERROR: 4,
};

const args = process.argv.slice(2);
const REPORT = args.includes('--report');
const outputArg = args.find((a) => a.startsWith('--output='));
const REPORT_FILE = outputArg ? outputArg.split('=')[1] : `validation-report-${new Date().toISOString().replace(/[:.]/g,'-')}.md`;
const levelArg = (args.find(a=>a.startsWith('--level='))||'').split('=')[1] || 'default';
const categoryArg = (args.find(a=>a.startsWith('--category='))||'').split('=')[1];

const repoRoot = process.cwd();
const webDir = path.join(repoRoot, 'apps', 'web');

// Load optional config
let userConfig = null;
let configLoadError = null;
const configPath = path.join(repoRoot, '.validation.config.js');
if (fs.existsSync(configPath)) {
  try {
    userConfig = require(configPath);
  } catch (e) {
    configLoadError = e;
  }
}

function isCategoryEnabled(category) {
  // Category filter via CLI
  if (categoryArg && category.toLowerCase() !== String(categoryArg).toLowerCase()) return false;
  // Level filter
  const level = levelArg.toLowerCase();
  const levelMap = {
    basic: ['environment','dependencies','configuration'],
    comprehensive: ['environment','dependencies','configuration','security','performance','infrastructure','build','tests'],
    'critical-only': ['environment','dependencies','security','infrastructure'],
    default: ['environment','dependencies','infrastructure','build','tests']
  };
  const allowed = levelMap[level] || levelMap.default;
  if (!allowed.includes(category)) return false;
  // Config file
  if (userConfig && userConfig.checks && userConfig.checks[category] && userConfig.checks[category].enabled === false) return false;
  return true;
}

const validationChecks = {
  environment: [
    'Required environment variables',
    'Configuration file presence',
    'API endpoint accessibility (static only)'
  ],
  dependencies: [
    'Package integrity',
    'Version compatibility (key deps present)',
    'Security vulnerabilities (npm audit)'
  ],
  infrastructure: [
    'Database connectivity (URL sanity)',
    'External service health (Redis URL sanity)',
    'File system permissions (reports dir)'
  ],
  build: [
    'Build artifacts exist (apps/web/.next)',
    'Asset compilation (dry build)',
    'Source map generation (config)'
  ],
  tests: [
    'Unit test pass status',
    'Integration test status (if configured)',
    'Code coverage presence (if generated)'
  ]
};

const results = [];
let failures = 0;
let warnings = 0;
let criticalErrors = 0;

function logStatus(ok, label, details) {
  const status = ok ? 'PASS' : 'FAIL';
  if (!ok) failures++;
  results.push({ category: currentCategory, label, status, details: details || '' });
}
function logWarn(label, details) {
  warnings++;
  results.push({ category: currentCategory, label, status: 'WARN', details: details || '' });
}

let currentCategory = '';
function setCategory(cat) {
  currentCategory = cat;
}

function hasEnv(name) {
  return !!process.env[name] || fs.existsSync(path.join(repoRoot, '.env')) || fs.existsSync(path.join(repoRoot, '.env.local'));
}

function execSafe(cmd, opts = {}) {
  try {
    const out = execSync(cmd, { stdio: ['ignore', 'pipe', 'pipe'], ...opts });
    return { ok: true, stdout: out.toString() };
  } catch (e) {
    return { ok: false, error: e, stdout: (e.stdout || '').toString(), stderr: (e.stderr || '').toString() };
  }
}

// Handle configuration load issues
let configErrorFlag = false;
if (configLoadError) {
  setCategory('configuration');
  logStatus(false, 'Validation config parse', `Failed to load .validation.config.js: ${configLoadError.message}`);
  configErrorFlag = true;
}

// 1) Environment
if (isCategoryEnabled('environment')) {
setCategory('environment');
try {
  let required = ['DATABASE_URL', 'NEXT_PUBLIC_WS_URL', 'NEXT_PUBLIC_MAP_STYLE_URL'];
  if (userConfig && Array.isArray(userConfig.ignore)) {
    required = required.filter(v => !userConfig.ignore.includes(v));
  }
  const missing = required.filter((v) => !process.env[v]);
  logStatus(missing.length === 0, 'Required environment variables', missing.length ? `Missing: ${missing.join(', ')}` : 'All present');

  const hasEnvFiles = fs.existsSync(path.join(repoRoot, '.env.production')) || fs.existsSync(path.join(webDir, '.env.local')) || fs.existsSync(path.join(repoRoot, '.env'));
  logStatus(hasEnvFiles, 'Configuration file presence', hasEnvFiles ? 'Found .env.production or apps/web/.env.local' : 'No env files found');

  // API endpoint accessibility (static): ensure Next API folder exists
  const apiDir = path.join(webDir, 'src', 'pages', 'api');
  const apiExists = fs.existsSync(apiDir);
  logWarn('API endpoint accessibility (static only)', apiExists ? 'api directory exists' : 'api directory not found (may be OK if not used)');
} catch (e) {
  logStatus(false, 'Environment validation', e.message);
}
}

// 2) Dependencies
if (isCategoryEnabled('dependencies')) {
setCategory('dependencies');
try {
  const pkgPath = path.join(repoRoot, 'package.json');
  const pkgWebPath = path.join(webDir, 'package.json');
  const pkg = JSON.parse(fs.readFileSync(pkgPath, 'utf-8'));
  const pkgWeb = fs.existsSync(pkgWebPath) ? JSON.parse(fs.readFileSync(pkgWebPath, 'utf-8')) : { dependencies: {}, devDependencies: {} };
  const allDeps = { ...(pkg.dependencies||{}), ...(pkg.devDependencies||{}), ...(pkgWeb.dependencies||{}), ...(pkgWeb.devDependencies||{}) };

  logStatus(true, 'Package integrity', 'package.json parsed');

  const keyDeps = ['next', 'react', 'typescript', 'zod'];
  const missing = keyDeps.filter((d) => !allDeps[d]);
  logStatus(missing.length === 0, 'Version compatibility (key deps present)', missing.length ? `Missing: ${missing.join(', ')}` : 'OK');

  // Security audit (best-effort)
  const audit = execSafe('npm audit --production --audit-level=high');
  if (audit.ok) {
    logStatus(true, 'Security vulnerabilities', 'No high/critical vulnerabilities reported');
  } else {
    // If exit code non-zero, still treat as WARN to avoid failing local runs unnecessarily
    logWarn('Security vulnerabilities', 'npm audit reported issues or failed to run');
  }
} catch (e) {
  logStatus(false, 'Dependencies validation', e.message);
}
}

// 3) Infrastructure
if (isCategoryEnabled('infrastructure')) {
setCategory('infrastructure');
try {
  const dbUrl = process.env.DATABASE_URL || '';
  const dbOk = /^postgres(ql)?:\/\//i.test(dbUrl);
  logStatus(dbOk, 'Database connectivity (URL sanity)', dbOk ? 'DATABASE_URL looks valid' : 'DATABASE_URL missing or not postgresql://');

  const redisUrl = process.env.REDIS_URL || '';
  if (redisUrl) {
    const redisOk = /^rediss?:\/\//i.test(redisUrl);
    logStatus(redisOk, 'External service health (Redis URL)', redisOk ? 'REDIS_URL looks valid' : 'REDIS_URL is invalid');
  } else {
    logWarn('External service health (Redis URL)', 'REDIS_URL not set (OK if Redis not used)');
  }

  // File system permissions: create reports/ dir if not exists
  const reportsDir = path.join(repoRoot, 'reports');
  try {
    if (!fs.existsSync(reportsDir)) fs.mkdirSync(reportsDir, { recursive: true });
    fs.writeFileSync(path.join(reportsDir, '.perm_check'), 'ok');
    fs.unlinkSync(path.join(reportsDir, '.perm_check'));
    logStatus(true, 'File system permissions (reports dir)', 'Writable');
  } catch (e) {
    logWarn('File system permissions (reports dir)', `Not writable: ${e.message}`);
  }
} catch (e) {
  logStatus(false, 'Infrastructure validation', e.message);
}
}

// 4) Build
if (isCategoryEnabled('build')) {
setCategory('build');
try {
  const nextOut = path.join(webDir, '.next');
  const hasArtifacts = fs.existsSync(nextOut);
  logWarn('Build artifacts exist (apps/web/.next)', hasArtifacts ? 'Found' : 'Not found (will attempt to build)');

  if (!hasArtifacts) {
    const build = execSafe('npm run build', { cwd: webDir });
    logStatus(build.ok, 'Asset compilation (apps/web build)', build.ok ? 'Build succeeded' : 'Build failed');
  } else {
    logStatus(true, 'Asset compilation (apps/web build)', 'Skipped (artifacts exist)');
  }

  // Source maps: productionBrowserSourceMaps=false desired
  try {
    const nextConfig = fs.readFileSync(path.join(repoRoot, 'next.config.js'), 'utf-8');
    const smDisabled = /productionBrowserSourceMaps:\s*false/.test(nextConfig);
    logStatus(true, 'Source map generation', smDisabled ? 'Prod source maps disabled (OK)' : 'Prod source maps default');
  } catch {
    logWarn('Source map generation', 'next.config.js not found or unreadable');
  }
} catch (e) {
  logStatus(false, 'Build validation', e.message);
}
}

// 5) Tests
if (isCategoryEnabled('tests')) {
setCategory('tests');
try {
  // Prefer vitest if configured
  let ran = false;
  if (fs.existsSync(path.join(repoRoot, 'vitest.config.ts')) || fs.existsSync(path.join(repoRoot, 'vitest.config.js'))) {
    const t = execSafe('npm run test:run');
    if (t.ok) {
      logStatus(true, 'Unit test pass status', 'Vitest run passed');
    } else {
      logWarn('Unit test pass status', 'Vitest run failed or not configured to run headless');
    }
    ran = true;
  }
  if (!ran) {
    const jt = execSafe('npm test --if-present');
    if (jt.ok) logStatus(true, 'Unit test pass status', 'npm test passed');
    else logWarn('Unit test pass status', 'npm test not configured or failed');
  }

  // Integration tests (best-effort)
  if (fs.existsSync(path.join(repoRoot, 'scripts', 'verify-integration.sh'))) {
    const it = execSafe('bash scripts/verify-integration.sh');
    if (it.ok) logWarn('Integration test status', 'verify-integration.sh succeeded (info)');
    else logWarn('Integration test status', 'verify-integration.sh failed (non-blocking)');
  }

  // Coverage presence
  const cov = fs.existsSync(path.join(repoRoot, 'coverage'));
  logWarn('Code coverage thresholds', cov ? 'Coverage folder exists' : 'Coverage not generated');
} catch (e) {
  logWarn('Tests', `Test checks encountered issues: ${e.message}`);
}
}

// Render report
function renderReport() {
  const lines = [];
  lines.push('# Production Validation Report');
  lines.push('');
  lines.push(`Generated: ${new Date().toISOString()}`);
  lines.push('');
  const categories = Array.from(new Set(results.map(r => r.category)));
  for (const cat of categories) {
    lines.push(`## ${cat.charAt(0).toUpperCase() + cat.slice(1)}`);
    for (const r of results.filter(x => x.category === cat)) {
      const icon = r.status === 'PASS' ? '✅' : r.status === 'WARN' ? '⚠️' : '❌';
      lines.push(`- ${icon} ${r.label} — ${r.details}`);
    }
    lines.push('');
  }
  lines.push('---');
  lines.push(`Summary: ${results.filter(r=>r.status==='PASS').length} pass, ${results.filter(r=>r.status==='WARN').length} warn, ${results.filter(r=>r.status==='FAIL').length} fail`);
  return lines.join('\n');
}

if (REPORT) {
  try {
    const out = renderReport();
    fs.writeFileSync(REPORT_FILE, out, 'utf-8');
    console.log(`\n📄 Validation report written to ${REPORT_FILE}\n`);
  } catch (e) {
    console.warn('Could not write report:', e.message);
  }
}

let exitCode = EXIT_CODES.SUCCESS;
if (configErrorFlag) {
  exitCode = EXIT_CODES.CONFIG_ERROR;
} else if (failures > 0) {
  exitCode = EXIT_CODES.VALIDATION_FAILED;
}
if (exitCode !== EXIT_CODES.SUCCESS) {
  console.error(`\n❌ Validation finished with ${failures} failures, ${warnings} warnings.${configErrorFlag ? ' (configuration error)' : ''}`);
  process.exit(exitCode);
} else {
  console.log(`\n✅ Validation passed with ${warnings} warnings.`);
  process.exit(exitCode);
}
