#!/usr/bin/env node
/**
 * scripts/release/warm_endpoints.mjs
 * Warms critical endpoints and prints simple latency stats.
 */
import fs from 'node:fs';
import path from 'node:path';

const args = process.argv.slice(2);
let envName = 'stage';
for (let i = 0; i < args.length; i++) {
  if (args[i] === '--env') envName = args[++i] || envName;
}

const cfgPath = path.join(process.cwd(), 'config', 'rollout.json');
const cfg = fs.existsSync(cfgPath) ? JSON.parse(fs.readFileSync(cfgPath, 'utf8')) : {};
const envCfg = cfg.environments?.[envName] || {};

async function ping(url) {
  const t0 = Date.now();
  try {
    const res = await fetch(url, { method: 'GET' });
    const ms = Date.now() - t0;
    console.log(`[warm] ${url} -> ${res.status} in ${ms}ms`);
    return { ok: res.ok, ms };
  } catch (e) {
    const ms = Date.now() - t0;
    console.log(`[warm] ${url} -> ERROR in ${ms}ms: ${e?.message || e}`);
    return { ok: false, ms };
  }
}

(async function main(){
  const urls = [envCfg.metricsUrl, envCfg.miniaggUrl].filter(Boolean);
  if (urls.length === 0) {
    console.error('[warm] No URLs found for environment. Check config/rollout.json');
    process.exit(1);
  }
  let anyFail = false;
  for (const u of urls) {
    const r = await ping(u);
    if (!r.ok) anyFail = true;
  }
  process.exit(anyFail ? 2 : 0);
})();
