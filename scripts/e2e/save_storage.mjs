#!/usr/bin/env node
// scripts/e2e/save_storage.mjs
// Usage: node scripts/e2e/save_storage.mjs --env ci --project web --file e2e/.auth/storage-state.json
// Requires: SUPABASE_URL, SUPABASE_SERVICE_ROLE

import fs from 'fs';
import path from 'path';
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';

function arg(name, def = undefined) {
  const i = process.argv.indexOf(`--${name}`);
  return i > -1 ? process.argv[i + 1] : def;
}

const url = process.env.SUPABASE_URL;
const key = process.env.SUPABASE_SERVICE_ROLE || process.env.SUPABASE_SERVICE_ROLE_KEY;
if (!url || !key) {
  console.error('[save_storage] Missing SUPABASE_URL or SUPABASE_SERVICE_ROLE');
  process.exit(2);
}

const env = arg('env', process.env.E2E_ENV || 'ci');
const project = arg('project', process.env.E2E_PROJECT || 'web');
const file = arg('file', 'e2e/.auth/storage-state.json');

const p = path.resolve(file);
if (!fs.existsSync(p)) {
  console.error('[save_storage] File not found:', p);
  process.exit(1);
}

const storage = JSON.parse(fs.readFileSync(p, 'utf8'));
const db = createClient(url, key, { auth: { persistSession: false } });

const { error } = await db.from('e2e_auth_storage').upsert(
  { env, project, storage, updated_at: new Date().toISOString() },
  { onConflict: 'env,project' }
);

if (error) {
  console.error('[save_storage] upsert failed:', error.message);
  process.exit(1);
}
console.log('[save_storage] upserted auth storage for', env, project);
