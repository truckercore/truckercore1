#!/usr/bin/env node
// Simple check to ensure provider profiles exist
import fs from 'fs';
import path from 'path';

const REQUIRED = ['Custom_HMAC.md', 'Stripe.md', 'GitHub.md', 'Slack.md', 'Twilio.md'];
const base = path.resolve(process.cwd(), 'docs', 'providers');
let ok = true;
for (const f of REQUIRED) {
  const p = path.join(base, f);
  const exists = fs.existsSync(p);
  console.log(JSON.stringify({ check: 'provider_profile', file: p, exists }));
  if (!exists) ok = false;
}
if (!ok) {
  console.error('Missing required provider profiles.');
  process.exitCode = 1;
}
