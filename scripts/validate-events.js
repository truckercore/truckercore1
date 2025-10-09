// scripts/validate-events.js
// Validate event fixtures against JSON Schemas to block schema drift in CI.
import fs from 'node:fs';
import path from 'node:path';
import process from 'node:process';
import Ajv from 'ajv';
import addFormats from 'ajv-formats';

const ajv = new Ajv({ allErrors: true, strict: false });
addFormats(ajv);

function findTopics() {
  const fixturesRoot = path.join(process.cwd(), 'fixtures', 'events');
  if (!fs.existsSync(fixturesRoot)) return [];
  return fs
    .readdirSync(fixturesRoot, { withFileTypes: true })
    .filter((d) => d.isDirectory())
    .map((d) => d.name);
}

function loadSchema(topic, version = 'v1') {
  const schemaPath = path.join(process.cwd(), 'schemas', 'events', topic, `${version}.schema.json`);
  if (!fs.existsSync(schemaPath)) {
    throw new Error(`Schema not found for topic=${topic} version=${version} at ${schemaPath}`);
  }
  return JSON.parse(fs.readFileSync(schemaPath, 'utf8'));
}

function loadFixtures(topic) {
  const dir = path.join(process.cwd(), 'fixtures', 'events', topic);
  if (!fs.existsSync(dir)) return [];
  return fs
    .readdirSync(dir)
    .filter((f) => f.endsWith('.json'))
    .map((f) => JSON.parse(fs.readFileSync(path.join(dir, f), 'utf8')));
}

async function main() {
  const topicsEnv = process.env.EVENT_TOPICS; // optional comma-separated override
  const topics = topicsEnv && topicsEnv.trim().length > 0 ? topicsEnv.split(',').map((s) => s.trim()) : findTopics();

  if (topics.length === 0) {
    console.log('[contracts] No fixtures found (fixtures/events/*). Skipping.');
    process.exit(0);
    return;
  }

  let failed = 0;
  for (const t of topics) {
    const schema = loadSchema(t, 'v1');
    const validate = ajv.compile(schema);
    const fixtures = loadFixtures(t);
    if (fixtures.length === 0) {
      console.warn(`[contracts] No fixtures for ${t}; skipping topic.`);
      continue;
    }
    for (const fx of fixtures) {
      const ok = validate(fx);
      if (!ok) {
        console.error(`Schema validation failed for ${t}:`, validate.errors);
        failed++;
      }
    }
  }

  if (failed > 0) {
    console.error(`[contracts] Validation failed for ${failed} fixture(s).`);
    process.exit(1);
  } else {
    console.log('[contracts] All fixtures valid.');
  }
}

main().catch((e) => {
  console.error('[contracts] Fatal error:', e);
  process.exit(1);
});
