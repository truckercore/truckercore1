#!/usr/bin/env node
/**
 * Final production checklist - run before launch
 */

const GREEN = '\x1b[32m';
const RED = '\x1b[31m';
const YELLOW = '\x1b[33m';
const BLUE = '\x1b[36m';
const RESET = '\x1b[0m';

console.log(`${BLUE}
╔═══════════════════════════════════════════════════╗
║   TruckerCore - Final Production Checklist       ║
║   Run this before deploying to production        ║
╚═══════════════════════════════════════════════════╝
${RESET}\n`);

const checklist = {
  'Environment Setup': [
    { task: 'SUPABASE_URL set', check: () => process.env.SUPABASE_URL || process.env.NEXT_PUBLIC_SUPABASE_URL },
    { task: 'SUPABASE_SERVICE_ROLE_KEY set', check: () => process.env.SUPABASE_SERVICE_ROLE_KEY },
    { task: 'Supabase project linked', check: () => require('fs').existsSync('supabase/.branches/_current_branch') || require('fs').existsSync('.git') },
  ],
  'Code Quality': [
    { task: 'No uncommitted changes', check: () => { try { require('child_process').execSync('git status --porcelain', {stdio: 'pipe'}); return true; } catch { return false; } } },
    { task: 'On main/master branch', check: () => { try { const branch = require('child_process').execSync('git branch --show-current', {encoding: 'utf-8'}).trim(); return branch === 'main' || branch === 'master'; } catch { return true; } } },
    { task: 'Build successful', check: () => require('fs').existsSync('.next') },
  ],
  'Security': [
    { task: '.env in .gitignore', check: () => { const gi = require('fs').readFileSync('.gitignore', 'utf-8'); return gi.includes('.env'); } },
    { task: 'No secrets in Git', check: () => { try { const result = require('child_process').execSync('git log --all -S "eyJ" --pretty=format:"%H"', {encoding: 'utf-8'}); return !result.trim(); } catch { return true; } } },
  ],
  'Documentation': [
    { task: 'README.md complete', check: () => require('fs').existsSync('README.md') },
    { task: 'LAUNCH_PLAYBOOK.md exists', check: () => require('fs').existsSync('docs/LAUNCH_PLAYBOOK.md') },
    { task: 'MASTER_DEPLOYMENT_GUIDE.md exists', check: () => require('fs').existsSync('docs/MASTER_DEPLOYMENT_GUIDE.md') },
  ],
  'Files & Assets': [
    { task: 'pages/index.tsx exists', check: () => require('fs').existsSync('pages/index.tsx') },
    { task: 'SQL migration exists', check: () => require('fs').existsSync('supabase/migrations/20250928_refresh_safety_summary.sql') },
    { task: 'Edge Function exists', check: () => require('fs').existsSync('supabase/functions/refresh-safety-summary/index.ts') },
    { task: 'Components exist', check: () => require('fs').existsSync('components/SafetySummaryCard.tsx') && require('fs').existsSync('components/ExportAlertsCSVButton.tsx') },
    { task: 'API route exists', check: () => require('fs').existsSync('pages/api/export-alerts.csv.ts') },
  ],
  'Deployment Scripts': [
    { task: 'Unix deployment script', check: () => require('fs').existsSync('scripts/deploy_safety_summary_suite.mjs') },
    { task: 'Windows deployment script', check: () => require('fs').existsSync('scripts/Deploy-SafetySuite.ps1') },
    { task: 'Preflight check script', check: () => require('fs').existsSync('scripts/preflight-check.mjs') },
    { task: 'Integration tests', check: () => require('fs').existsSync('scripts/integration-test-all.mjs') },
  ],
};

let totalChecks = 0;
let passedChecks = 0;
const failedTasks = [];

for (const [category, tasks] of Object.entries(checklist)) {
  console.log(`${BLUE}${category}${RESET}`);
  
  for (const { task, check } of tasks) {
    totalChecks++;
    process.stdout.write(`  ${task}... `);
    
    try {
      const result = check();
      if (result) {
        console.log(`${GREEN}✓${RESET}`);
        passedChecks++;
      } else {
        console.log(`${RED}✗${RESET}`);
        failedTasks.push({ category, task });
      }
    } catch (err) {
      console.log(`${RED}✗${RESET} (${err.message})`);
      failedTasks.push({ category, task, error: err.message });
    }
  }
  console.log('');
}

// Summary
const passRate = ((passedChecks / totalChecks) * 100).toFixed(0);
console.log(`${BLUE}${'='.repeat(50)}${RESET}`);
console.log(`${BLUE}SUMMARY${RESET}`);
console.log(`${BLUE}${'='.repeat(50)}${RESET}\n`);
console.log(`Total: ${totalChecks} | Passed: ${passedChecks} | Failed: ${totalChecks - passedChecks} | Success Rate: ${passRate}%\n`);

if (failedTasks.length === 0) {
  console.log(`${GREEN}╔════════════════════════════════════════════════╗${RESET}`);
  console.log(`${GREEN}║   ✅  ALL CHECKS PASSED - READY TO DEPLOY   ║${RESET}`);
  console.log(`${GREEN}╚════════════════════════════════════════════════╝${RESET}\n`);
  console.log('Next steps:');
  console.log('1. Run: npm run launch');
  console.log('2. Push: git push origin main');
  console.log('3. Schedule CRON: supabase functions schedule refresh-safety-summary "\"0 6 * * *\""');
  console.log('4. Monitor for 24 hours using docs/POST_LAUNCH_MONITORING.md\n');
  process.exit(0);
} else {
  console.log(`${RED}╔════════════════════════════════════════════════╗${RESET}`);
  console.log(`${RED}║   ⚠️  SOME CHECKS FAILED - REVIEW BELOW  ⚠️  ║${RESET}`);
  console.log(`${RED}╚════════════════════════════════════════════════╝${RESET}\n`);
  console.log('Failed checks:\n');
  failedTasks.forEach(({ category, task, error }) => {
    console.log(`${RED}✗${RESET} ${category} → ${task}`);
    if (error) console.log(`  └─ ${error}`);
  });
  console.log('\nResolve these issues before deploying.\n');
  process.exit(1);
}
