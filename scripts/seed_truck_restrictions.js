#!/usr/bin/env node
/*
Seed Truck Restrictions into Supabase

Usage:
  # 1) Ensure you have Node 18+
  # 2) Copy scripts/data/truck_restrictions.sample.json to your dataset path (or replace with full dataset)
  # 3) Set environment variables:
  #      SUPABASE_URL=https://<your-project>.supabase.co
  #      SUPABASE_SERVICE_ROLE_KEY=eyJhbGciOiJI... (Service role key)
  # 4) Run:
  #      node scripts/seed_truck_restrictions.js path/to/dataset.json

Table (DDL suggestion if not exists):
  create table if not exists public.truck_restrictions (
    id bigserial primary key,
    state_code text not null,
    category text not null check (category in ('low_clearance','weigh_station','restricted_route')),
    description text not null,
    location jsonb, -- { "lat": number, "lng": number } optional
    geom geometry, -- optional if PostGIS enabled
    created_at timestamptz default now()
  );
  -- Idempotency on (state_code, category, description)
  create unique index if not exists idx_tr_unique on public.truck_restrictions (state_code, category, description);

Notes:
  - This script performs upserts based on (state_code, category, description).
  - Batches inserts to avoid large payloads.
*/

import fs from 'node:fs';
import path from 'node:path';
import process from 'node:process';
import { createClient } from '@supabase/supabase-js';

const SUPABASE_URL = process.env.SUPABASE_URL;
const SERVICE_KEY = process.env.SUPABASE_SERVICE_ROLE_KEY;

if (!SUPABASE_URL || !SERVICE_KEY) {
  console.error('[seed] Missing SUPABASE_URL or SUPABASE_SERVICE_ROLE_KEY');
  process.exit(1);
}

const args = process.argv.slice(2);
if (args.length === 0) {
  console.error('[seed] Usage: node scripts/seed_truck_restrictions.js <dataset.json>');
  process.exit(1);
}

const datasetPath = path.resolve(process.cwd(), args[0]);
if (!fs.existsSync(datasetPath)) {
  console.error(`[seed] Dataset not found: ${datasetPath}`);
  process.exit(1);
}

/**
 * Expected JSON shape:
 * {
 *   "NH": {
 *     "lowClearances": ["..."],
 *     "weighStations": ["..."],
 *     "restrictedRoutes": ["..."]
 *   },
 *   "NJ": { ... }
 * }
 */
const raw = fs.readFileSync(datasetPath, 'utf-8');
const data = JSON.parse(raw);

const supabase = createClient(SUPABASE_URL, SERVICE_KEY, {
  auth: { persistSession: false },
});

function chunk(arr, size) {
  const out = [];
  for (let i = 0; i < arr.length; i += size) out.push(arr.slice(i, i + size));
  return out;
}

function buildRows(state, entries, category) {
  if (!Array.isArray(entries)) return [];
  return entries
    .filter((s) => typeof s === 'string' && s.trim().length > 0)
    .map((description) => ({
      state_code: state,
      category,
      description: description.trim(),
    }));
}

async function upsertBatch(rows) {
  if (rows.length === 0) return;
  const { error } = await supabase
    .from('truck_restrictions')
    .upsert(rows, { onConflict: 'state_code,category,description' })
    .select('id');
  if (error) throw error;
}

async function main() {
  console.log(`[seed] Starting seeding from ${datasetPath}`);
  const allRows = [];
  for (const [state, obj] of Object.entries(data)) {
    const lc = buildRows(state, obj.lowClearances || obj.low_clearances || obj.low_clearance, 'low_clearance');
    const ws = buildRows(state, obj.weighStations || obj.weigh_stations || obj.stations, 'weigh_station');
    const rr = buildRows(state, obj.restrictedRoutes || obj.restricted_routes || obj.restricted, 'restricted_route');
    allRows.push(...lc, ...ws, ...rr);
  }
  console.log(`[seed] Prepared ${allRows.length} rows`);
  const chunks = chunk(allRows, 500);
  let done = 0;
  for (const c of chunks) {
    await upsertBatch(c);
    done += c.length;
    console.log(`[seed] Upserted ${done}/${allRows.length}`);
  }
  console.log('[seed] Completed successfully');
}

main().catch((e) => {
  console.error('[seed] Failed:', e);
  process.exit(1);
});
