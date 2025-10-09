#!/usr/bin/env node
/**
 * scripts/release/evidence_capture.mjs
 * Writes an evidence markdown file under release/evidence/ with key links.
 */
import fs from 'node:fs';
import path from 'node:path';

const args = process.argv.slice(2);
let envName = 'stage';
let ticket = '';
for (let i = 0; i < args.length; i++) {
  if (args[i] === '--env') envName = args[++i] || envName;
  else if (args[i] === '--ticket') ticket = args[++i] || '';
}

const cfgPath = path.join(process.cwd(), 'config', 'rollout.json');
const cfg = fs.existsSync(cfgPath) ? JSON.parse(fs.readFileSync(cfgPath, 'utf8')) : {};
const envCfg = cfg.environments?.[envName] || {};

const now = new Date();
const ts = now.toISOString().replace(/[:.]/g, '-');
const outDir = path.join(process.cwd(), 'release', 'evidence');
fs.mkdirSync(outDir, { recursive: true });
const outPath = path.join(outDir, `evidence-${envName}-${ts}.md`);

const md = `# Evidence — ${envName.toUpperCase()} — ${now.toISOString()}

Ticket: ${ticket || 'n/a'}

Builds
- App: ${process.env.APP_VERSION || ''} (${process.env.GIT_COMMIT || ''})

Endpoints
- Base: ${envCfg.baseUrl || ''}
- Metrics: ${envCfg.metricsUrl || ''}
- MiniAgg: ${envCfg.miniaggUrl || ''}

Dashboards
- Overview: ${envCfg.dashboards?.overview || ''}
- Alerts: ${envCfg.dashboards?.alerts || ''}

Store
- iOS TF: ${envCfg.store?.iosTestFlight || ''}
- Android Internal: ${envCfg.store?.androidInternal || ''}

SLOs
- freshnessMaxSeconds: ${cfg.slos?.freshnessMaxSeconds}
- readP95MaxMs: ${cfg.slos?.readP95MaxMs}
- ingestEvalP95MaxMs: ${cfg.slos?.ingestEvalP95MaxMs}

Screenshots/Notes
- Attach screenshots of dashboards and store consoles here.
`;

fs.writeFileSync(outPath, md);
console.log(`[evidence] Wrote ${outPath}`);
