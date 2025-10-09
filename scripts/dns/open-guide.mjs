#!/usr/bin/env node
// Open DNS configuration guide

import { exec } from 'child_process';
import { existsSync } from 'fs';
import { fileURLToPath } from 'url';
import { dirname, join } from 'path';

const __filename = fileURLToPath(import.meta.url);
const __dirname = dirname(__filename);

const colors = {
  blue: '\x1b[34m',
  yellow: '\x1b[33m',
  reset: '\x1b[0m',
};

console.log(`${colors.blue}📖 Opening DNS Configuration Guide...${colors.reset}`);
console.log('');

// Path to DNS configuration doc
const docPath = join(__dirname, '../../DNS_CONFIGURATION.md');

if (existsSync(docPath)) {
  // Try to open in default editor
  const isWindows = process.platform === 'win32';
  const isMac = process.platform === 'darwin';
  
  if (isMac) {
    exec(`open "${docPath}"`);
  } else if (isWindows) {
    exec(`start "" "${docPath}"`);
  } else {
    exec(`xdg-open "${docPath}" 2>/dev/null || cat "${docPath}"`);
  }
  
  console.log(`${colors.yellow}Guide opened: ${docPath}${colors.reset}`);
} else {
  console.log(`${colors.yellow}⚠️  Guide not found at: ${docPath}${colors.reset}`);
  console.log('');
  console.log('Quick DNS Configuration:');
  console.log('');
  console.log('Add these records in your DNS provider (e.g., Namecheap):');
  console.log('');
  console.log('Type   Host       Value                                TTL');
  console.log('────────────────────────────────────────────────────────────');
  console.log('A      @          76.76.21.21                         Auto');
  console.log('CNAME  www        cname.vercel-dns.com                Auto');
  console.log('CNAME  app        cname.vercel-dns.com                Auto');
  console.log('CNAME  api        <ref>.functions.supabase.co         Auto');
  console.log('CNAME  downloads  <ref>.supabase.co                   Auto');
  console.log('');
  console.log('Replace <ref> with your Supabase project reference.');
}

console.log('');
console.log('After updating DNS:');
console.log('  1. Wait 5-10 minutes for propagation');
console.log('  2. npm run dns:check');
