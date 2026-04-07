#!/usr/bin/env node
// Validates all example fixtures in tests/fixtures/events/** against schemas in schemas/events/**
import { readFile } from 'node:fs/promises';
import { globby } from 'globby';
import Ajv from 'ajv';
import addFormats from 'ajv-formats';
import path from 'node:path';
import process from 'node:process';

async function main() {
  const ajv = new Ajv({ strict: true, allErrors: true });
  addFormats(ajv);

  // Load all schemas
  const schemaFiles = await globby('schemas/events/*/v*.schema.json');
  const schemas = {};
  for (const file of schemaFiles) {
    const raw = await readFile(file, 'utf8');
    const schema = JSON.parse(raw);
    const id = schema.$id || file;
    schemas[id] = schema;
    ajv.addSchema(schema, id);
  }

  // Map topic+version to schema id/file
  const topicVersionToSchema = {};
  for (const file of schemaFiles) {
    const p = path.parse(file);
    const topic = path.basename(path.dirname(file)); // events/<topic>/
    const version = p.name.replace('.schema', '').split('.')[0].replace('v', ''); // v1.schema -> 1
    const id = JSON.parse(await readFile(file, 'utf8')).$id || file;
    topicVersionToSchema[`${topic}@${version}`] = id;
  }

  // Validate fixtures
  const fixtureFiles = await globby('tests/fixtures/events/*/*.json');
  let failures = 0;

  for (const file of fixtureFiles) {
    const raw = await readFile(file, 'utf8');
    const data = JSON.parse(raw);

    // Basic envelope checks before schema selection
    const topic = data?.topic;
    const version = String(data?.version || '');
    if (!topic || !version) {
      console.error(`❌ ${file}: missing topic/version`);
      failures++;
      continue;
    }

    const schemaId = topicVersionToSchema[`${topic}@${version}`];
    if (!schemaId) {
      console.error(`❌ ${file}: no schema found for ${topic}@${version}`);
      failures++;
      continue;
    }

    const validate = ajv.getSchema(schemaId);
    if (!validate) {
      console.error(`❌ ${file}: failed to load validator for ${schemaId}`);
      failures++;
      continue;
    }

    const ok = validate(data);
    if (!ok) {
      console.error(`❌ ${file}: schema validation failed`);
      for (const err of validate.errors || []) {
        console.error(`   → ${err.instancePath || '(root)'} ${err.message} ${err.params ? JSON.stringify(err.params) : ''}`);
      }
      failures++;
    } else {
      console.log(`✅ ${file}: valid against ${schemaId}`);
    }
  }

  if (failures > 0) {
    console.error(`\n${failures} validation error(s)`);
    process.exit(1);
  }
  console.log('\nAll fixtures valid.');
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});
