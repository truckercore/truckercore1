#!/usr/bin/env node
// CI-friendly DNS assertion (fails if DNS not ready)

import { exec } from 'child_process';
import { promisify } from 'util';

const execAsync = promisify(exec);

const CRITICAL_DOMAINS = [
  'truckercore.com',
  'www.truckercore.com',
  'app.truckercore.com',
];

const EXPECTED_VERCEL_IPS = ['76.76.21.21'];

async function assertDNS(domain) {
  try {
    const { stdout } = await execAsync(`dig +short ${domain} A`);
    const ips = stdout.trim().split('\n').filter(Boolean);
    
    if (ips.length === 0) {
      // Try CNAME
      const { stdout: cname } = await execAsync(`dig +short ${domain} CNAME`);
      const target = cname.trim();
      
      if (!target.includes('vercel')) {
        throw new Error(`${domain}: Not pointing to Vercel`);
      }
      return true;
    }

    // Check if any IP matches Vercel
    const hasVercelIP = ips.some(ip => EXPECTED_VERCEL_IPS.includes(ip));
    if (!hasVercelIP) {
      throw new Error(`${domain}: IP ${ips[0]} is not Vercel (expected 76.76.21.21)`);
    }

    return true;
  } catch (error) {
    throw new Error(`${domain}: ${error.message}`);
  }
}

async function main() {
  console.log('🔍 CI DNS Assertion Check\n');

  try {
    await Promise.all(CRITICAL_DOMAINS.map(assertDNS));
    console.log('✅ All critical DNS records configured correctly');
    console.log('');
    process.exit(0);
  } catch (error) {
    console.error('❌ DNS Configuration Error:');
    console.error(`   ${error.message}`);
    console.error('');
    console.error('This will cause production deployment to fail.');
    console.error('Fix DNS configuration before merging to main.');
    console.error('');
    console.error('Run locally:');
    console.error('  npm run dns:check');
    console.error('  npm run dns:guide');
    console.error('');
    process.exit(1);
  }
}

main().catch(error => {
  console.error('❌ Unexpected error:', error.message);
  process.exit(1);
});
