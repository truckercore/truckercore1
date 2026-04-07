#!/usr/bin/env node
// scripts/invoke_edge.mjs
// A simple HTTP invoker for Supabase Edge Functions without requiring the Supabase CLI.
// Usage examples:
//   node scripts/invoke_edge.mjs org_queue_worker
//   node scripts/invoke_edge.mjs admin_diagnostics_json
//   node scripts/invoke_edge.mjs synthetic_load --drivers=100 --hours=24 --chunk=2000 --org=<org-uuid>
// Env:
//   SUPABASE_FUNCTIONS_URL = https://<project-ref>.functions.supabase.co
//   SUPABASE_SERVICE_ROLE_KEY = <service role key>  (optional; include when function requires it)

import https from 'node:https';

const baseUrl = process.env.SUPABASE_FUNCTIONS_URL;
if (!baseUrl) {
  console.error('[invoke_edge] Missing SUPABASE_FUNCTIONS_URL');
  process.exit(2);
}

const args = process.argv.slice(2);
if (args.length === 0) {
  console.error('Usage: node scripts/invoke_edge.mjs <function_name> [--k=v ...]');
  process.exit(2);
}

const fn = args[0];
const kv = Object.fromEntries(
  args.slice(1).map((a) => {
    const m = a.match(/^--([^=]+)=(.*)$/);
    return m ? [m[1], m[2]] : [a.replace(/^--/, ''), true];
  })
);

function buildUrl() {
  const u = new URL(`${baseUrl.replace(/\/$/, '')}/${fn}`);
  // For synthetic_load, we support drivers/hours/chunk/org query params
  for (const [k, v] of Object.entries(kv)) {
    if (v === true) continue;
    u.searchParams.set(k, String(v));
  }
  return u.toString();
}

function request(method = 'GET') {
  const url = buildUrl();
  const headers = { 'Content-Type': 'application/json' };
  const srk = process.env.SUPABASE_SERVICE_ROLE_KEY;
  if (srk) headers['Authorization'] = `Bearer ${srk}`;

  const isPost = method === 'POST';
  const body = isPost ? JSON.stringify({}) : undefined;

  return new Promise((resolve, reject) => {
    const req = https.request(url, { method, headers }, (res) => {
      let data = '';
      res.on('data', (chunk) => (data += chunk));
      res.on('end', () => {
        const status = res.statusCode || 0;
        try {
          const json = JSON.parse(data || '{}');
          resolve({ status, json });
        } catch {
          resolve({ status, text: data });
        }
      });
    });
    req.on('error', reject);
    if (body) req.write(body);
    req.end();
  });
}

(async () => {
  try {
    const method = fn === 'org_queue_worker' ? 'POST' : 'GET';
    const { status, json, text } = await request(method);
    console.log(`[invoke_edge] ${fn} -> status ${status}`);
    console.log(json ?? text);
  } catch (e) {
    console.error('[invoke_edge] error:', e);
    process.exit(1);
  }
})();
