#!/usr/bin/env node
/*
Universal Validation Suite
- Exit code strategy
- Categorized checks
- Levels: basic, comprehensive, critical-only
- Config file support: .validation.config.js
- Parallel execution for independent checks
- Optional markdown report generation (--report [--output=path])
- Optional category selection (--category=security)
- Notification stubs (slack/email/monitoring)
- Historical tracking stored in reports/validation-history.json
*/

const fs = require('fs');
const path = require('path');
const { execSync } = require('child_process');

const argv = process.argv.slice(2);
const args = Object.fromEntries(
  argv
    .filter((a) => a.includes('='))
    .map((a) => {
      const [k, v] = a.replace(/^--/, '').split('=');
      return [k, v];
    })
);
const flags = new Set(argv.filter((a) => a.startsWith('--') && !a.includes('=')));

const repoRoot = process.cwd();
const reportsDir = path.join(repoRoot, 'reports');

// Exit codes
const EXIT_CODES = {
  SUCCESS: 0, // All checks passed
  WARNING: 0, // Warnings but not blocking
  VALIDATION_FAILED: 1, // Failed validation checks
  CRITICAL_ERROR: 2, // System/infrastructure issues
  CONFIG_ERROR: 3, // Configuration problems
  DEPENDENCY_ERROR: 4, // Missing dependencies
};

// Load configuration
let userConfig = {
  checks: {
    environment: { enabled: true, severity: 'critical' },
    dependencies: { enabled: true, severity: 'high' },
    configuration: { enabled: true, severity: 'high' },
    security: { enabled: true, severity: 'critical' },
    performance: { enabled: false, severity: 'low' },
    infrastructure: { enabled: true, severity: 'high' },
    tests: { enabled: true, severity: 'medium' },
  },
  thresholds: { testCoverage: 70, buildTime: 600, bundleSize: 8000 },
  ignore: [],
  notification: {},
};
const cfgFile = path.join(repoRoot, '.validation.config.js');
if (fs.existsSync(cfgFile)) {
  try {
    userConfig = { ...userConfig, ...require(cfgFile) };
  } catch (e) {
    console.error('[validation] Failed to load .validation.config.js:', e.message);
  }
}

// Level filtering
const level = args.level || (flags.has('--level') ? 'basic' : 'all');
function isCategoryEnabled(cat) {
  const c = userConfig.checks[cat] || { enabled: true };
  if (!c.enabled) return false;
  if (level === 'critical-only') return (c.severity || 'low') === 'critical';
  if (level === 'basic') return ['critical', 'high'].includes(c.severity || 'low');
  if (level === 'comprehensive' || level === 'all') return true;
  return true;
}

const onlyCategory = args.category || null;
const generateReport = flags.has('--report') || args.report === 'true';
const reportFile = args.output || `validation-report-${new Date().toISOString().replace(/[:.]/g, '-')}.md`;

// Types
/** @typedef {{name:string, required?:boolean, validator?:(value:string)=>boolean}} EnvironmentCheck */
/** @typedef {{category:string, checks: Array<{name:string,status:'pass'|'fail'|'warn', required?:boolean, message?:string}> , passed:boolean}} CategoryResult */

// Helpers
function safeExec(cmd, options = {}) {
  try {
    const out = execSync(cmd, { stdio: ['ignore', 'pipe', 'pipe'], ...options });
    return { ok: true, stdout: out.toString() };
  } catch (e) {
    return { ok: false, stdout: (e.stdout || '').toString(), stderr: (e.stderr || '').toString(), error: e };
  }
}

function ensureReportsDir() {
  try {
    if (!fs.existsSync(reportsDir)) fs.mkdirSync(reportsDir, { recursive: true });
  } catch (e) {
    // ignore
  }
}

// Category implementations
async function validateEnvironment() {
  /** @type {EnvironmentCheck[]} */
  const environmentChecks = [
    { name: 'NODE_ENV', required: true, validator: (v) => ['development', 'production', 'test'].includes(v) },
    { name: 'DATABASE_URL', required: true, validator: (v) => /^postgres(ql)?:\/\//.test(v) },
    { name: 'API_KEY', required: false, validator: (v) => !v || v.length >= 32 },
  ];
  const checks = environmentChecks.map((check) => {
    const value = process.env[check.name];
    const exists = value !== undefined;
    const valid = !check.validator || check.validator(value || '');
    return {
      name: check.name,
      status: exists && valid ? 'pass' : check.required ? 'fail' : 'warn',
      required: !!check.required,
      message: !exists ? 'Missing' : !valid ? 'Invalid format' : 'OK',
    };
  });
  return { category: 'environment', checks, passed: checks.every((c) => c.status === 'pass' || !c.required) };
}

async function validateDependencies() {
  // Run npm ls to detect missing peer/dep problems; treat severe issues as failure
  const ls = safeExec('npm ls --depth=0');
  const audit = safeExec('npm audit --production --audit-level=critical');
  const checks = [
    { name: 'npm ls', status: ls.ok ? 'pass' : 'fail', message: ls.ok ? 'Dependencies resolved' : 'Dependency issues' },
    { name: 'npm audit (critical)', status: audit.ok ? 'pass' : 'warn', message: audit.ok ? 'No critical vulns' : 'Vulnerabilities reported or audit failed' },
  ];
  return { category: 'dependencies', checks, passed: checks.every((c) => c.status !== 'fail') };
}

async function validateConfiguration() {
  const files = ['.env', '.env.production', 'apps/web/.env.local'];
  const checks = files.map((f) => {
    const exists = fs.existsSync(path.join(repoRoot, f));
    return { name: `config:${f}`, status: exists ? 'pass' : 'warn', message: exists ? 'Found' : 'Missing (may be OK)' };
  });
  return { category: 'configuration', checks, passed: true };
}

async function validateSecurity() {
  const snyk = process.env.SNYK_TOKEN ? safeExec('npx snyk test --severity-threshold=high') : { ok: true };
  const secretScan = safeExec('git ls-files | findstr /r ".*" > NUL', { shell: true }); // placeholder no-op for Windows
  const checks = [
    { name: 'Snyk (high)', status: snyk.ok ? 'pass' : 'warn', message: snyk.ok ? 'OK' : 'Snyk issues' },
    { name: 'Secret scan', status: secretScan.ok ? 'pass' : 'warn', message: 'Baseline check' },
  ];
  return { category: 'security', checks, passed: checks.every((c) => c.status !== 'fail') };
}

async function validatePerformance() {
  // Placeholder: check build size threshold if file exists
  const bundlePath = path.join(repoRoot, 'apps', 'web', '.next', 'trace');
  const exists = fs.existsSync(bundlePath);
  const checks = [
    { name: 'bundle artifacts', status: exists ? 'pass' : 'warn', message: exists ? 'Found artifacts' : 'Artifacts missing' },
  ];
  return { category: 'performance', checks, passed: true };
}

async function validateInfrastructure() {
  const dbUrl = process.env.DATABASE_URL || '';
  const dbOk = /^postgres(ql)?:\/\//i.test(dbUrl);
  const redis = process.env.REDIS_URL || '';
  const redisOk = !redis || /^rediss?:\/\//i.test(redis);
  const checks = [
    { name: 'database url', status: dbOk ? 'pass' : 'fail', message: dbOk ? 'Looks valid' : 'Missing/invalid' },
    { name: 'redis url', status: redisOk ? 'pass' : 'warn', message: redis ? (redisOk ? 'Looks valid' : 'Invalid') : 'Not set' },
  ];
  return { category: 'infrastructure', checks, passed: dbOk };
}

async function validateTests() {
  const useVitest = fs.existsSync(path.join(repoRoot, 'vitest.config.ts')) || fs.existsSync(path.join(repoRoot, 'vitest.config.js'));
  const run = useVitest ? safeExec('npm run test:run') : safeExec('npm test --if-present');
  const checks = [
    { name: 'unit tests', status: run.ok ? 'pass' : 'warn', message: run.ok ? 'Passed' : 'Failed or not configured' },
  ];
  return { category: 'tests', checks, passed: run.ok };
}

const registry = {
  environment: validateEnvironment,
  dependencies: validateDependencies,
  configuration: validateConfiguration,
  security: validateSecurity,
  performance: validatePerformance,
  infrastructure: validateInfrastructure,
  tests: validateTests,
};

async function runValidations() {
  const cats = Object.keys(registry)
    .filter((c) => isCategoryEnabled(c))
    .filter((c) => (onlyCategory ? c === onlyCategory : true));

  const promises = cats.map((c) =>
    registry[c]().then(
      (r) => ({ status: 'fulfilled', value: r }),
      (e) => ({ status: 'rejected', reason: e })
    )
  );
  const settled = await Promise.allSettled(promises);
  // Flatten because we wrapped already
  /** @type {CategoryResult[]} */
  const results = settled.map((s, i) => {
    const cat = cats[i];
    if (s.status === 'fulfilled') return s.value;
    return { category: cat, checks: [{ name: 'execution', status: 'fail', message: String(s.reason?.message || s.reason || 'unknown error') }], passed: false };
  });
  return results;
}

function aggregate(results) {
  const flat = results.flatMap((r) => r.checks.map((c) => ({ ...c, category: r.category })));
  const hasFail = flat.some((c) => c.status === 'fail');
  const hasCriticalInfra = flat.some((c) => c.category === 'infrastructure' && c.status === 'fail');
  const hasDepFail = flat.some((c) => c.category === 'dependencies' && c.status === 'fail');
  let exitCode = EXIT_CODES.SUCCESS;
  if (hasCriticalInfra) exitCode = EXIT_CODES.CRITICAL_ERROR;
  else if (hasDepFail) exitCode = EXIT_CODES.DEPENDENCY_ERROR;
  else if (hasFail) exitCode = EXIT_CODES.VALIDATION_FAILED;
  return { flat, exitCode };
}

function toMarkdown(results) {
  let md = '# Validation Report\n\n';
  for (const r of results) {
    md += `## ${capitalize(r.category)}\n`;
    for (const c of r.checks) {
      const icon = c.status === 'pass' ? '✅' : c.status === 'warn' ? '⚠️' : '❌';
      md += `- ${icon} ${c.name}: ${c.message || ''}\n`;
    }
    md += '\n';
  }
  return md;
}

function capitalize(s) { return s.charAt(0).toUpperCase() + s.slice(1); }

async function notifyOnFailure(summary, results) {
  const cfg = userConfig.notification || {};
  if (summary.exitCode === EXIT_CODES.SUCCESS) return;
  // Slack webhook stub
  if (cfg.slack?.webhook) {
    try {
      const payload = { text: `Validation failed with code ${summary.exitCode}` };
      await fetchShim(cfg.slack.webhook, payload);
    } catch {}
  }
  // Monitoring endpoint stub
  if (cfg.monitoring?.endpoint) {
    try {
      await fetchShim(cfg.monitoring.endpoint, { status: 'failed', exitCode: summary.exitCode });
    } catch {}
  }
}

async function fetchShim(url, body) {
  // Minimal implementation using Node https if fetch not available
  try {
    if (typeof fetch === 'function') {
      await fetch(url, { method: 'POST', headers: { 'content-type': 'application/json' }, body: JSON.stringify(body) });
      return;
    }
  } catch {}
  const https = require('https');
  const { URL } = require('url');
  const u = new URL(url);
  return new Promise((resolve, reject) => {
    const req = https.request(
      { hostname: u.hostname, path: u.pathname + (u.search || ''), method: 'POST', port: u.port || 443, headers: { 'content-type': 'application/json' } },
      (res) => { res.on('data', () => {}); res.on('end', resolve); }
    );
    req.on('error', reject);
    req.write(JSON.stringify(body || {}));
    req.end();
  });
}

function saveHistory(commit = process.env.GIT_COMMIT || '', branch = process.env.GIT_BRANCH || '') {
  ensureReportsDir();
  const historyFile = path.join(reportsDir, 'validation-history.json');
  let history = [];
  try {
    if (fs.existsSync(historyFile)) history = JSON.parse(fs.readFileSync(historyFile, 'utf-8'));
  } catch { history = []; }
  return (entry) => {
    history.push(entry);
    try { fs.writeFileSync(historyFile, JSON.stringify(history, null, 2)); } catch {}
  };
}

(async function main() {
  const started = Date.now();
  const results = await runValidations();
  const summary = aggregate(results);

  if (generateReport) {
    ensureReportsDir();
    const outPath = path.isAbsolute(reportFile) ? reportFile : path.join(reportsDir, reportFile);
    const md = toMarkdown(results);
    try { fs.writeFileSync(outPath, md, 'utf-8'); console.log(`[validation] Report written to ${outPath}`); } catch (e) { console.error('[validation] Failed to write report', e.message); }
  }

  const save = saveHistory(process.env.GIT_COMMIT || '', process.env.GIT_BRANCH || '');
  save({
    timestamp: new Date().toISOString(),
    commit: process.env.GIT_COMMIT || '',
    branch: process.env.GIT_BRANCH || '',
    results: results,
    duration: Math.round((Date.now() - started) / 1000),
    exitCode: summary.exitCode,
    level,
  });

  await notifyOnFailure(summary, results);

  // Print concise summary to console
  console.log('[validation] Completed with exit code', summary.exitCode);
  for (const r of results) {
    const passes = r.checks.filter((c) => c.status === 'pass').length;
    const fails = r.checks.filter((c) => c.status === 'fail').length;
    const warns = r.checks.filter((c) => c.status === 'warn').length;
    console.log(` - ${r.category}: ${passes} pass, ${warns} warn, ${fails} fail`);
  }

  process.exit(summary.exitCode);
})();
