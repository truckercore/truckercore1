#!/usr/bin/env node
// Validates presence of policy URLs and docs
import fs from 'node:fs';
import path from 'node:path';

function fail(msg){ console.error(`[policies] ${msg}`); process.exit(1); }
function ok(msg){ console.log(`[policies] ${msg}`); }

const urlsPath = path.join(process.cwd(), 'docs', 'policies', 'urls.json');
if (!fs.existsSync(urlsPath)) fail('docs/policies/urls.json missing');
let urls;
try { urls = JSON.parse(fs.readFileSync(urlsPath, 'utf8')); } catch (e) { fail('urls.json invalid JSON'); }
const required = ['privacyUrl', 'termsUrl'];
for (const k of required) {
  const v = (urls?.[k] || '').toString();
  if (!v || !/^https?:\/\//i.test(v)) fail(`${k} must be a non-empty http(s) URL`);
}
// Check docs exist
const priv = path.join(process.cwd(), 'docs', 'policies', 'PRIVACY_POLICY.md');
const terms = path.join(process.cwd(), 'docs', 'policies', 'TERMS_EULA.md');
if (!fs.existsSync(priv)) fail('PRIVACY_POLICY.md missing');
if (!fs.existsSync(terms)) fail('TERMS_EULA.md missing');

ok('Policies and URLs validated');
