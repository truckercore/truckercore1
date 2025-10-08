#!/usr/bin/env node
/**
 * Pre-flight check before deployment
 * Validates environment, dependencies, and readiness
 */

import { existsSync } from 'fs';
import { execSync } from 'child_process';

const GREEN = '\x1b[32m';
const RED = '\x1b[31m';
const YELLOW = '\x1b[33m';
const BLUE = '\x1b[36m';
const RESET = '\x1b[0m';

let criticalIssues = 0;
let warnings = 0;
let passed = 0;

const checks = [];

function log(color, symbol, message) {
  console.log(`${color}${symbol}${RESET} ${message}`);
}

function check(name, fn, critical = false) {
  process.stdout.write(`Checking ${name}... `);
  try {
    const result = fn();
    if (result === true || result === undefined) {
      console.log(`${GREEN}✓${RESET}`);
      passed++;
      checks.push({ name, status: 'pass', critical });
      return true;
    } else {
      console.log(`${YELLOW}⚠${RESET} ${result}`);
      warnings++;
      checks.push({ name, status: 'warn', message: result, critical });
      return false;
    }
  } catch (err) {
    console.log(`${RED}✗${RESET} ${err.message}`);
    if (critical) criticalIssues++;
    else warnings++;
    checks.push({ name, status: 'fail', message: err.message, critical });
    return false;
  }
}

function section(title) {
  console.log(`\n${BLUE}=== ${title} ===${RESET}\n`);
}

function cmd(command) {
  try {
    execSync(command, { stdio: 'pipe', encoding: 'utf-8' });
    return true;
  } catch (_err) {
    throw new Error(`Command failed: ${command}`);
  }
}

console.log(`${BLUE}
╔═══════════════════════════════════════╗
║   TruckerCore Pre-Flight Check v1.0   ║
╚═══════════════════════════════════════╝
${RESET}`);

// ===== ENVIRONMENT =====
section('Environment');

check('Node.js version ≥18', () => {
  const version = process.version.match(/^v(\d+)/)?.[1];
  if (!version || parseInt(version) < 18) {
    throw new Error(`Node ${process.version} detected, need ≥18`);
  }
}, true);

check('npm installed', () => cmd('npm --version'), true);

check('Git installed', () => cmd('git --version'));

check('Supabase CLI installed', () => {
  try {
    cmd('supabase --version');
    return true;
  } catch (err) {
    return 'Install: npm install -g supabase';
  }
}, true);

// ===== DEPENDENCIES =====
section('Dependencies');

check('node_modules exists', () => {
  if (!existsSync('node_modules')) {
    throw new Error('Run: npm install');
  }
}, true);

check('package-lock.json exists', () => {
  if (!existsSync('package-lock.json')) {
    return 'No lock file (acceptable but not ideal)';
  }
});

check('Dependencies up to date', () => {
  try {
    execSync('npm outdated --json', { stdio: 'pipe' });
    return true;
  } catch (_err) {
    // npm outdated exits with 1 if outdated packages exist
    return 'Some packages outdated (non-critical)';
  }
});

// ===== ENVIRONMENT VARIABLES =====
section('Environment Variables');

const requiredVars = [
  'SUPABASE_URL',
  'SUPABASE_SERVICE_ROLE_KEY'
];

const optionalVars = [
  'SUPABASE_ANON_KEY',
  'NEXT_PUBLIC_SUPABASE_URL',
  'NEXT_PUBLIC_SUPABASE_ANON_KEY'
];

requiredVars.forEach(varName => {
  check(`${varName} set`, () => {
    const value = process.env[varName] || process.env[`NEXT_PUBLIC_${varName}`];
    if (!value) {
      throw new Error(`Missing required variable: ${varName}`);
    }
    if (value.length < 10) {
      throw new Error(`${varName} seems invalid (too short)`);
    }
  }, true);
});

optionalVars.forEach(varName => {
  check(`${varName} set`, () => {
    const value = process.env[varName];
    if (!value) {
      return 'Not set (optional)';
    }
  });
});

// ===== FILES & STRUCTURE =====
section('Files & Structure');

const requiredFiles = [
  'package.json',
  'apps/web/src/app/page.tsx',
  'apps/web/src/app/layout.tsx',
  'supabase/migrations/20250928_refresh_safety_summary.sql',
  'supabase/functions/refresh-safety-summary/index.ts',
  'apps/web/src/components/safety/SafetySummaryCard.tsx',
  'apps/web/src/components/exports/ExportAlertsCSVButton.tsx',
  'apps/web/src/components/TopRiskCorridors.tsx',
  'apps/web/src/app/api/exports/alerts/route.ts'
];

requiredFiles.forEach(file => {
  check(file, () => {
    if (!existsSync(file)) {
      throw new Error('File missing');
    }
  }, true);
});

const requiredDocs = [
  'docs/MASTER_DEPLOYMENT_GUIDE.md',
  'docs/deployment/DEPLOYMENT_SUMMARY.md',
  'docs/homepage/HOMEPAGE_SUMMARY.md',
  'README.md'
];

requiredDocs.forEach(doc => {
  check(doc, () => {
    if (!existsSync(doc)) {
      return 'Documentation missing (non-critical)';
    }
  });
});

// ===== ASSETS =====
section('Assets');

const assets = [
  { file: 'apps/web/public/favicon.ico', critical: false },
  { file: 'apps/web/public/og-image.png', critical: false },
  { file: 'apps/web/public/apple-touch-icon.png', critical: false },
  { file: 'apps/web/public/manifest.json', critical: true },
  { file: 'apps/web/public/robots.txt', critical: true }
];

assets.forEach(({ file, critical }) => {
  check(file, () => {
    if (!existsSync(file)) {
      if (critical) {
        throw new Error('Required file missing');
      } else {
        return 'Missing (use placeholder for now)';
      }
    }
  }, critical);
});

// ===== GIT STATUS =====
section('Git Status');

check('Git repository initialized', () => {
  if (!existsSync('.git')) {
    throw new Error('Not a git repository');
  }
}, true);

check('No uncommitted changes', () => {
  try {
    const status = execSync('git status --porcelain', { encoding: 'utf-8' });
    if (status.trim()) {
      return 'Uncommitted changes exist (commit before deploy)';
    }
  } catch (_err) {
    throw new Error('Cannot check git status');
  }
});

check('On main/master branch', () => {
  try {
    const branch = execSync('git branch --show-current', { encoding: 'utf-8' }).trim();
    if (branch !== 'main' && branch !== 'master') {
      return `On branch '${branch}' (deploy from main recommended)`;
    }
  } catch (_err) {
    return 'Cannot determine branch';
  }
});

// ===== BUILD =====
section('Build');

check('Next.js builds successfully', () => {
  log(YELLOW, '⏳', 'Building... (this may take a minute)');
  try {
    execSync('npm run build', { stdio: 'pipe' });
    return true;
  } catch (_err) {
    throw new Error('Build failed - check logs');
  }
}, true);

check('Build output exists', () => {
  if (!existsSync('.next') && !existsSync('apps/web/.next')) {
    throw new Error('No .next directory after build');
  }
}, true);

// ===== SECURITY =====
section('Security');

check('No secrets in Git history', () => {
  try {
    const result = execSync('git log --all -S "eyJ" --pretty=format:"%H"', { encoding: 'utf-8' });
    if (result.trim()) {
      throw new Error('Potential secrets found in Git history!');
    }
  } catch (err) {
    if (String(err.message).includes('Potential secrets')) {
      throw err;
    }
    return 'Cannot check (acceptable)';
  }
}, true);

check('.env in .gitignore', () => {
  if (existsSync('.gitignore')) {
    const gitignore = require('fs').readFileSync('.gitignore', 'utf-8');
    if (!gitignore.includes('.env')) {
      throw new Error('.env not in .gitignore');
    }
  } else {
    return 'No .gitignore found';
  }
}, true);

check('npm audit (critical vulnerabilities)', () => {
  try {
    execSync('npm audit --audit-level=critical --json', { stdio: 'pipe' });
    return true;
  } catch (_err) {
    return 'Critical vulnerabilities found - run: npm audit fix';
  }
});

// ===== SUMMARY =====
const total = checks.length;
const failRate = ((criticalIssues / total) * 100).toFixed(1);
const warnRate = ((warnings / total) * 100).toFixed(1);
const passRate = ((passed / total) * 100).toFixed(1);

console.log(`\n${BLUE}${'='.repeat(50)}${RESET}`);
console.log(`${BLUE}SUMMARY${RESET}`);
console.log(`${BLUE}${'='.repeat(50)}${RESET}\n`);

console.log(`Total Checks: ${total}`);
console.log(`${GREEN}✓ Passed:${RESET} ${passed} (${passRate}%)`);
console.log(`${YELLOW}⚠ Warnings:${RESET} ${warnings} (${warnRate}%)`);
console.log(`${RED}✗ Critical Issues:${RESET} ${criticalIssues} (${failRate}%)`);

if (criticalIssues > 0) {
  console.log(`\n${RED}╔════════════════════════════════════╗${RESET}`);
  console.log(`${RED}║  ⚠️  CRITICAL ISSUES FOUND  ⚠️   ║${RESET}`);
  console.log(`${RED}╚════════════════════════════════════╝${RESET}\n`);
  
  console.log('The following critical issues must be fixed:\n');
  checks.filter(c => c.status === 'fail' && c.critical).forEach(c => {
    console.log(`${RED}✗${RESET} ${c.name}`);
    console.log(`  └─ ${c.message}\n`);
  });
  
  console.log(`${RED}Cannot proceed with deployment.${RESET}`);
  process.exit(1);
} else if (warnings > 0) {
  console.log(`\n${YELLOW}╔════════════════════════════════════╗${RESET}`);
  console.log(`${YELLOW}║     ⚠️  WARNINGS PRESENT  ⚠️      ║${RESET}`);
  console.log(`${YELLOW}╚════════════════════════════════════╝${RESET}\n`);
  
  console.log('The following warnings should be reviewed:\n');
  checks.filter(c => c.status === 'warn' || (c.status === 'fail' && !c.critical)).forEach(c => {
    console.log(`${YELLOW}⚠${RESET} ${c.name}`);
    if (c.message) console.log(`  └─ ${c.message}\n`);
  });
  
  console.log(`${YELLOW}Deployment can proceed, but review warnings.${RESET}`);
  process.exit(0);
} else {
  console.log(`\n${GREEN}╔════════════════════════════════════╗${RESET}`);
  console.log(`${GREEN}║   ✅  ALL CHECKS PASSED  ✅       ║${RESET}`);
  console.log(`${GREEN}╚════════════════════════════════════╝${RESET}\n`);
  
  console.log(`${GREEN}System is ready for deployment!${RESET}\n`);
  console.log('Next steps:');
  console.log('1. Deploy Safety Suite: npm run deploy:safety-suite');
  console.log('2. Deploy Homepage: git push origin main');
  console.log('3. Verify: npm run verify:all');
  console.log('4. Monitor for 24 hours\n');
  
  process.exit(0);
}
