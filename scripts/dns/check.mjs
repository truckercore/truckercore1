#!/usr/bin/env node
// DNS verification script for TruckerCore domains

import { exec } from 'child_process';
import { promisify } from 'util';

const execAsync = promisify(exec);

// ANSI colors
const colors = {
  green: '\x1b[32m',
  red: '\x1b[31m',
  yellow: '\x1b[33m',
  blue: '\x1b[34m',
  reset: '\x1b[0m',
};

// Expected DNS configurations
const EXPECTED_CONFIG = {
  'truckercore.com': {
    type: 'A',
    targets: ['76.76.21.21'],
    description: 'Root domain → Vercel',
  },
  'www.truckercore.com': {
    type: 'CNAME',
    // Accept both generic and specific Vercel CNAMEs
    pattern: /^(cname\.vercel-dns\.com|[a-f0-9]+\.vercel-dns-\d+\.com)\.?$/,
    description: 'WWW subdomain → Vercel',
  },
  'app.truckercore.com': {
    type: 'CNAME',
    // Accept both generic and specific Vercel CNAMEs
    pattern: /^(cname\.vercel-dns\.com|[a-f0-9]+\.vercel-dns-\d+\.com)\.?$/,
    description: 'App subdomain → Vercel',
  },
  'api.truckercore.com': {
    type: 'CNAME',
    pattern: /^[a-z0-9]+\.functions\.supabase\.co\.?$/,
    description: 'API subdomain → Supabase Edge Functions',
    expected: 'viqrwlzdtosxjzjvtxnr.functions.supabase.co',
  },
  'downloads.truckercore.com': {
    type: 'CNAME',
    pattern: /^[a-z0-9]+\.supabase\.co\.?$/,
    description: 'Downloads subdomain → Supabase Storage',
    expected: 'viqrwlzdtosxjzjvtxnr.supabase.co',
  },
};

// Get domains from command line or use defaults
const domains = process.argv.slice(2).length > 0 
  ? process.argv.slice(2)
  : Object.keys(EXPECTED_CONFIG);

async function checkDNS(domain) {
  const expected = EXPECTED_CONFIG[domain];
  if (!expected) {
    return { domain, status: 'unknown', message: 'Not in expected config' };
  }

  try {
    // Check for A records
    if (expected.type === 'A') {
      const { stdout } = await execAsync(`dig +short ${domain} A`);
      const records = stdout.trim().split('\n').filter(Boolean);
      
      if (records.length === 0) {
        return { 
          domain, 
          status: 'error', 
          message: 'No A record found',
          expected: expected.targets[0],
        };
      }

      const match = records.some(r => expected.targets.includes(r));
      if (match) {
        return { 
          domain, 
          status: 'success', 
          message: `✅ ${records[0]}`,
          description: expected.description,
        };
      } else {
        return { 
          domain, 
          status: 'error', 
          message: `❌ Wrong IP: ${records[0]}`,
          expected: expected.targets[0],
          description: expected.description,
        };
      }
    }

    // Check for CNAME records
    if (expected.type === 'CNAME') {
      const { stdout } = await execAsync(`dig +short ${domain} CNAME`);
      const cname = stdout.trim();

      if (!cname) {
        return { 
          domain, 
          status: 'error', 
          message: 'No CNAME record found',
          expected: expected.targets ? expected.targets[0] : 'Supabase domain',
        };
      }

      // Check pattern match (for Supabase domains)
      if (expected.pattern) {
        const match = expected.pattern.test(cname);
        if (match) {
          return { 
            domain, 
            status: 'success', 
            message: `✅ ${cname}`,
            description: expected.description,
          };
        } else {
          return { 
            domain, 
            status: 'error', 
            message: `❌ Wrong target: ${cname}`,
            expected: 'Should match *.supabase.co or *.functions.supabase.co',
            description: expected.description,
          };
        }
      }

      // Check exact match (for Vercel domains)
      const match = expected.targets && expected.targets.some(t => cname === t);
      if (match) {
        return { 
          domain, 
          status: 'success', 
          message: `✅ ${cname}`,
          description: expected.description,
        };
      } else {
        return { 
          domain, 
          status: 'error', 
          message: `❌ Wrong CNAME: ${cname}`,
          expected: expected.targets[0],
          description: expected.description,
        };
      }
    }
  } catch (error) {
    return { 
      domain, 
      status: 'error', 
      message: `Error: ${error.message}`,
    };
  }
}

async function main() {
  console.log(`${colors.blue}╔════════════════════════════════════════════════╗${colors.reset}`);
  console.log(`${colors.blue}║     TruckerCore DNS Verification              ║${colors.reset}`);
  console.log(`${colors.blue}╚════════════════════════════════════════════════╝${colors.reset}`);
  console.log('');

  const results = await Promise.all(domains.map(checkDNS));

  let allGood = true;
  let errors = [];

  results.forEach(result => {
    const statusColor = result.status === 'success' ? colors.green : colors.red;
    console.log(`${result.domain}`);
    console.log(`  ${result.description || ''}`);
    console.log(`  ${statusColor}${result.message}${colors.reset}`);
    
    if (result.expected && result.status !== 'success') {
      console.log(`  ${colors.yellow}Expected: ${result.expected}${colors.reset}`);
    }
    
    console.log('');

    if (result.status !== 'success') {
      allGood = false;
      errors.push(result);
    }
  });

  // Summary
  console.log('═'.repeat(50));
  if (allGood) {
    console.log(`${colors.green}✅ All DNS records configured correctly!${colors.reset}`);
    console.log('');
    console.log('Next steps:');
    console.log('  1. npm run deploy');
    console.log('  2. npm run check:production');
    process.exit(0);
  } else {
    console.log(`${colors.red}❌ ${errors.length} DNS record(s) need attention${colors.reset}`);
    console.log('');
    console.log('To fix these issues:');
    console.log('  1. npm run dns:guide');
    console.log('  2. Update DNS records in your provider');
    console.log('  3. Wait 5-10 minutes for propagation');
    console.log('  4. npm run dns:check (re-run this check)');
    process.exit(1);
  }
}

main().catch(console.error);
