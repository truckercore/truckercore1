#!/usr/bin/env node
/**
 * scripts/release/health_check.mjs
 * Validates SLOs by scraping /metrics and applying simple heuristics.
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
const slos = cfg.slos || { freshnessMaxSeconds: 120, readP95MaxMs: 150, ingestEvalP95MaxMs: 10 };

function fail(msg){ console.error(`[health] FAIL: ${msg}`); process.exitCode = 2; }
function warn(msg){ console.warn(`[health] WARN: ${msg}`); }
function ok(msg){ console.log(`[health] ${msg}`); }

async function getText(url){
  const res = await fetch(url, { method: 'GET' });
  if (!res.ok) throw new Error(`${res.status}`);
  return res.text();
}

function parseFloatAfter(line){
  const m = line.match(/\s([0-9.Ee+-]+)\s*$/);
  return m ? Number(m[1]) : NaN;
}

(async function main(){
  if (!envCfg.metricsUrl) fail('metricsUrl missing for env');
  let metrics;
  try {
    metrics = await getText(envCfg.metricsUrl);
  } catch(e){
    fail(`Unable to GET metrics: ${e?.message || e}`);
    return;
  }
  // Freshness check
  const freshLine = metrics.split('\n').find(l => l.startsWith('miniagg_freshness_seconds_max '));
  if (!freshLine) {
    warn('miniagg freshness metric not found');
  } else {
    const fresh = parseFloatAfter(freshLine);
    if (isFinite(fresh) && fresh <= slos.freshnessMaxSeconds) ok(`freshness OK: ${fresh}s ≤ ${slos.freshnessMaxSeconds}s`);
    else fail(`freshness ${fresh}s exceeds ${slos.freshnessMaxSeconds}s`);
  }

  // Ingest eval latency p95 proxy: ratio within le=10ms buckets
  const bucket10 = metrics.split('\n').filter(l => l.startsWith('geofence_eval_latency_ms_bucket') && l.includes('le="10"'));
  const countLines = metrics.split('\n').filter(l => l.startsWith('geofence_eval_latency_ms_count'));
  let bSum = 0, cSum = 0;
  for (const l of bucket10) bSum += parseFloatAfter(l) || 0;
  for (const l of countLines) cSum += parseFloatAfter(l) || 0;
  if (cSum > 0) {
    const frac = bSum / cSum;
    if (frac >= 0.95) ok(`ingest eval p95 proxy OK (>=95% within 10ms): ${(frac*100).toFixed(1)}%`);
    else fail(`ingest eval p95 proxy LOW: ${(frac*100).toFixed(1)}% within 10ms (<95%)`);
  } else {
    warn('No geofence eval counts yet; skip eval p95 proxy');
  }

  // Exit with PASS/FAIL code
  if (process.exitCode && process.exitCode !== 0) {
    console.error('[health] One or more checks failed.');
    process.exit(process.exitCode);
  } else {
    ok('All checks passed or warnings only.');
  }
})();
