// seed_truck_restrictions.mjs
// Node seeder for truck_restrictions table
//
// Reads /data/state_restrictions.json (50-state object) and upserts rows into Supabase.
// Optionally geocodes each description into a POINT geometry when GEOCODE=1.
//
// ENV VARS (can be placed in .env.local at repo root):
//   SUPABASE_URL              e.g., https://<your-project>.supabase.co
//   SUPABASE_SERVICE_ROLE     service role key (used as Bearer/apikey)
//   GOOGLE_MAPS_KEY           (optional) enable geocoding if provided and GEOCODE=1
//   GEOCODE                   (optional) set to "1" to enable geocoding
//
// USAGE:
//   1) Put your full JSON into data/state_restrictions.json (same shape as sample)
//   2) Set env vars in .env.local or shell
//      $env:SUPABASE_URL="https://<proj>.supabase.co"
//      $env:SUPABASE_SERVICE_ROLE="<service role key>"
//      # optional
//      $env:GOOGLE_MAPS_KEY="<maps api key>"
//      $env:GEOCODE="1"
//   3) Run: node seed_truck_restrictions.mjs

import fs from 'node:fs/promises';
import path from 'node:path';
import process from 'node:process';

// Prefer Node 18+ global fetch; fallback to node-fetch if unavailable
let fetchFn = globalThis.fetch;
if (!fetchFn) {
  const mod = await import('node-fetch');
  fetchFn = mod.default;
}
const fetch = fetchFn;

// Load .env.local if present (simple parser, no dependency)
async function loadDotEnvLocal() {
  try {
    const envPath = path.resolve(process.cwd(), '.env.local');
    const txt = await fs.readFile(envPath, 'utf8');
    for (const lineRaw of txt.split(/\r?\n/)) {
      const line = lineRaw.trim();
      if (!line || line.startsWith('#')) continue;
      const eq = line.indexOf('=');
      if (eq <= 0) continue;
      const key = line.slice(0, eq).trim();
      let val = line.slice(eq + 1).trim();
      if ((val.startsWith('"') && val.endsWith('"')) || (val.startsWith("'") && val.endsWith("'"))) {
        val = val.slice(1, -1);
      }
      if (!process.env[key]) process.env[key] = val;
    }
  } catch (_) {
    // ignore if missing
  }
}
await loadDotEnvLocal();

const { SUPABASE_URL, SUPABASE_SERVICE_ROLE, GOOGLE_MAPS_KEY, GEOCODE } = process.env;

const headers = {
  apikey: SUPABASE_SERVICE_ROLE ?? '',
  Authorization: `Bearer ${SUPABASE_SERVICE_ROLE ?? ''}`,
  'Content-Type': 'application/json',
};

function sleep(ms) {
  return new Promise((r) => setTimeout(r, ms));
}

async function upsertRow(state, category, description, point) {
  const body = {
    state_code: state,
    category,
    description,
    location: point ? `SRID=4326;POINT(${point.lng} ${point.lat})` : null,
    source: 'manual_v1',
  };
  const res = await fetch(`${SUPABASE_URL}/rest/v1/truck_restrictions`, {
    method: 'POST',
    headers: { ...headers, Prefer: 'resolution=merge-duplicates' },
    body: JSON.stringify([body]),
  });
  if (!res.ok) {
    const t = await res.text();
    throw new Error(`Upsert failed: ${res.status} ${t}`);
  }
}

async function geocodeText(state, category, description) {
  if (!GEOCODE || !GOOGLE_MAPS_KEY) return null;
  const q = `${description}, ${state}, USA`;
  const url = `https://maps.googleapis.com/maps/api/geocode/json?address=${encodeURIComponent(q)}&key=${GOOGLE_MAPS_KEY}`;
  const r = await fetch(url);
  if (!r.ok) return null;
  const j = await r.json();
  const best = j.results?.[0];
  if (!best) return null;
  const { lat, lng } = best.geometry.location;
  return { lat, lng };
}

function* itemsFromDict(dict) {
  for (const [state, groups] of Object.entries(dict)) {
    for (const desc of groups.lowClearances ?? []) {
      yield [state, 'low_clearance', desc];
    }
    for (const desc of groups.weighStations ?? []) {
      yield [state, 'weigh_station', desc];
    }
    for (const desc of groups.restrictedRoutes ?? []) {
      yield [state, 'restricted_route', desc];
    }
  }
}

async function readDataset() {
  // Option A (repo): data/seed/overlays//
  //  - Supports either a single us_overlays.json or multiple per-state JSON files
  const overlaysDir = path.resolve(process.cwd(), 'data', 'seed', 'overlays');
  try {
    const stat = await fs.stat(overlaysDir);
    if (stat.isDirectory()) {
      // Prefer a single consolidated file if present
      const consolidated = path.join(overlaysDir, 'us_overlays.json');
      try {
        const raw = await fs.readFile(consolidated, 'utf8');
        console.log(`[seed] Using dataset: ${consolidated}`);
        return JSON.parse(raw);
      } catch (_) {
        // Merge all *.json files into one state dictionary
        const files = (await fs.readdir(overlaysDir)).filter((f) => f.toLowerCase().endsWith('.json'));
        if (files.length > 0) {
          const dict = {};
          for (const f of files) {
            const p = path.join(overlaysDir, f);
            try {
              const txt = await fs.readFile(p, 'utf8');
              const j = JSON.parse(txt);
              // If file is a single-state object like {"NH": {...}} merge directly
              // or if it's an object with lowClearances/weighStations/restrictedRoutes, infer state from filename
              const keys = Object.keys(j);
              if (keys.length === 1 && /^[A-Z]{2}$/.test(keys[0])) {
                dict[keys[0]] = j[keys[0]];
              } else {
                const m = f.match(/^([A-Za-z]{2})/);
                if (m) {
                  dict[m[1].toUpperCase()] = j;
                }
              }
            } catch (e) {
              console.warn(`[seed] Skip dataset file ${p}: ${e instanceof Error ? e.message : e}`);
            }
          }
          const statesFound = Object.keys(dict).length;
          if (statesFound > 0) {
            console.log(`[seed] Using dataset from directory: ${overlaysDir} (states=${statesFound})`);
            return dict;
          }
        }
      }
    }
  } catch (_) {
    // overlays dir not present; continue with legacy locations
  }

  // Legacy locations (kept for backward compatibility)
  const candidates = [
    path.resolve(process.cwd(), 'data', 'state_restrictions.json'),
    path.resolve(process.cwd(), 'restrictions.json'),
  ];
  for (const p of candidates) {
    try {
      const raw = await fs.readFile(p, 'utf8');
      console.log(`[seed] Using dataset: ${p}`);
      return JSON.parse(raw);
    } catch (_) {
      // try next
    }
  }
  console.error('[seed] No dataset found. Expected Option A: data/seed/overlays/ (preferred) or data/state_restrictions.json, or restrictions.json at repo root.');
  process.exit(1);
}

async function main() {
  if (!SUPABASE_URL || !SUPABASE_SERVICE_ROLE) {
    console.error('Missing SUPABASE_URL or SUPABASE_SERVICE_ROLE in env.');
    process.exit(1);
  }

  const dict = await readDataset();

  let i = 0;
  let geoHits = 0;

  for (const [state, category, description] of itemsFromDict(dict)) {
    try {
      let point = null;
      if (GEOCODE) {
        point = await geocodeText(state, category, description);
        if (point) geoHits++;
        await sleep(120); // gentle throttle when geocoding
      }
      await upsertRow(state, category, description, point);
      i++;
      if (i % 50 === 0) console.log(`Processed ${i} rows (geocoded ${geoHits})…`);
    } catch (e) {
      const msg = e instanceof Error ? e.message : String(e);
      console.warn(`Skip (${state}/${category}): ${description}\n  -> ${msg}`);
    }
  }

  console.log(`Done. Rows processed: ${i}. Geocoded: ${geoHits}.`);
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});
