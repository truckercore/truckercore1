#!/usr/bin/env ts-node

/**
 * Simple environment validation script.
 * Reads .env and reports missing variables for configured integrations.
 */

import * as fs from 'fs';
import * as path from 'path';

function parseEnvFile(filePath: string): Record<string, string> {
  const map: Record<string, string> = {};
  if (!fs.existsSync(filePath)) return map;
  const content = fs.readFileSync(filePath, 'utf8');
  for (const line of content.split('\n')) {
    const trimmed = line.trim();
    if (!trimmed || trimmed.startsWith('#')) continue;
    const idx = trimmed.indexOf('=');
    if (idx === -1) continue;
    const key = trimmed.slice(0, idx).trim();
    const val = trimmed.slice(idx + 1).trim();
    if (key) map[key] = val;
  }
  return map;
}

function validate(env: Record<string, string>) {
  const problems: string[] = [];

  // Supabase always required by app (unless using mock data)
  const supabaseRequired = true;
  if (supabaseRequired) {
    if (!env.SUPABASE_URL) problems.push('SUPABASE_URL is missing');
    if (!(env.SUPABASE_ANON || env.SUPABASE_ANON_KEY)) problems.push('SUPABASE_ANON (or SUPABASE_ANON_KEY) is missing');
  }

  // Optional integrations - only warn if a subset set
  const checkIntegration = (name: string, keys: string[]) => {
    const present = keys.filter((k) => !!env[k]);
    if (present.length > 0 && present.length < keys.length) {
      problems.push(`[${name}] Some keys set but not all: need ${keys.join(', ')}`);
    }
  };

  checkIntegration('Samsara', ['SAMSARA_API_KEY']);
  checkIntegration('Motive', ['MOTIVE_API_KEY']);
  checkIntegration('DAT', ['DAT_API_KEY', 'DAT_CUSTOMER_ID']);
  checkIntegration('Trimble', ['TRIMBLE_API_KEY']);
  checkIntegration('Geotab', ['GEOTAB_USERNAME', 'GEOTAB_PASSWORD', 'GEOTAB_DATABASE', 'GEOTAB_SERVER']);
  checkIntegration('Twilio', ['TWILIO_ACCOUNT_SID', 'TWILIO_AUTH_TOKEN', 'TWILIO_PHONE_NUMBER']);
  checkIntegration('SendGrid', ['SENDGRID_API_KEY', 'SENDGRID_FROM_EMAIL']);

  return problems;
}

(async () => {
  const envPath = path.join(process.cwd(), '.env');
  const env = parseEnvFile(envPath);
  const issues = validate(env);
  if (issues.length === 0) {
    console.log('✅ .env validation passed');
    process.exit(0);
  } else {
    console.error('❌ .env validation found issues:');
    for (const p of issues) console.error(' - ' + p);
    process.exit(1);
  }
})();
