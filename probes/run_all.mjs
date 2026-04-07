// probes/run_all.mjs
// Orchestrates probes and writes standardized outputs to files.
import { spawn } from 'node:child_process';
import { mkdirSync, writeFileSync } from 'node:fs';
import { resolve } from 'node:path';

const args = process.argv.slice(2);
const outIdx = args.indexOf('--out');
const outDir = resolve(process.cwd(), outIdx !== -1 ? args[outIdx + 1] : 'artifacts/probes');
mkdirSync(outDir, { recursive: true });

const tag = process.env.GITHUB_REF_NAME || process.env.TAG || 'local';
const sha = process.env.GITHUB_SHA || process.env.COMMIT || 'dev';
const tenant = process.env.PROBE_TENANT || 'global';

const probes = [
  { name: 'pos_hmac', file: resolve('probes/pos_hmac_invalid.mjs'), env: ['POS_WEBHOOK_URL','POS_WEBHOOK_SECRET'] },
  { name: 'rate_limit', file: resolve('probes/rate_limit.mjs'), env: ['RL_ENDPOINT'] },
];

function haveEnv(req) {
  return (req || []).every(k => (process.env[k] ?? '').length > 0);
}

function runProbe(p) {
  return new Promise((resolvePromise) => {
    if (!haveEnv(p.env)) {
      const line = { probe: p.name, status: 'degraded', ts: new Date().toISOString(), tenant, latency_ms: 0, details: { hint: 'skipped_missing_env', required: p.env }, evidence: {} };
      return resolvePromise({ code: 0, json: line });
    }
    const child = spawn(process.execPath, [p.file], { stdio: ['ignore', 'pipe', 'pipe'], env: process.env });
    let lastLine = '';
    child.stdout.on('data', (buf) => {
      const lines = buf.toString().trim().split(/\r?\n/);
      lastLine = lines[lines.length - 1];
    });
    child.stderr.on('data', () => {});
    child.on('close', (code) => {
      let parsed = null;
      try { parsed = JSON.parse(lastLine); } catch {}
      resolvePromise({ code, json: parsed });
    });
  });
}

let anyFail = false;
for (const p of probes) {
  const { code, json } = await runProbe(p);
  const obj = json || { probe: p.name, status: 'fail', ts: new Date().toISOString(), tenant, latency_ms: 0, details: { hint: 'no_output' }, evidence: {} };
  const fname = resolve(outDir, `${p.name}-${tenant}-${tag}-${sha}.json`);
  writeFileSync(fname, JSON.stringify(obj) + '\n');
  if (obj.status === 'fail') anyFail = true;
}

if (anyFail) process.exit(20);
