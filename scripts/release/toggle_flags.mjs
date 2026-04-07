#!/usr/bin/env node
/**
 * scripts/release/toggle_flags.mjs
 * Prints recommended environment flag toggles for staging/prod and quick guidance.
 * This script does NOT mutate remote envs; apply via your infra tool.
 */
import fs from 'node:fs';
import path from 'node:path';

const args = process.argv.slice(2);
const opts = { env: 'stage', enable: '', kill: '' };
for (let i = 0; i < args.length; i++) {
  const a = args[i];
  if (a === '--env') opts.env = args[++i] || opts.env;
  else if (a === '--enable') opts.enable = (args[++i] || '').toLowerCase();
  else if (a === '--kill') opts.kill = (args[++i] || '').toLowerCase();
}

const cfgPath = path.join(process.cwd(), 'config', 'rollout.json');
const cfg = fs.existsSync(cfgPath) ? JSON.parse(fs.readFileSync(cfgPath, 'utf8')) : {};
const envCfg = cfg.environments?.[opts.env] || {};

function printHeader(title){
  console.log(`\n=== ${title} ===`);
}

printHeader(`Target environment: ${opts.env}`);
console.log(JSON.stringify({
  baseUrl: envCfg.baseUrl,
  ingestUrl: envCfg.ingestUrl,
  metricsUrl: envCfg.metricsUrl,
  miniaggUrl: envCfg.miniaggUrl,
}, null, 2));

printHeader('Recommended env toggles (copy into your process/env manager)');
const enableGeofence = opts.enable.includes('geofence');
const killOn = opts.kill === 'on' || opts.kill === 'true' || opts.kill === '1';
console.log(`# Ingest server flags`);
console.log(`FLAG_GEOFENCE=${enableGeofence ? 'true' : 'false'}`);
console.log(`FLAG_GEOFENCE_KILL=${killOn ? 'true' : 'false'}`);
console.log(`# Optional tuning`);
console.log(`GEOF_EPSILON_M=20`);
console.log(`GEOF_CANDIDATE_RADIUS_KM=5`);
console.log(`GEOF_MAX_CANDIDATES=50`);
console.log(`# Dwell/Hot-reload`);
console.log(`DWELL_SECONDS=0`);
console.log(`ORG_SETTINGS_TTL_SECONDS=60`);

printHeader('Apply');
console.log(`- Update staging/prod service environment with above vars, then restart or hot-reload as needed.`);
console.log(`- Kill-switch: run with --kill on to bypass detection immediately.`);

