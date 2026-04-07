# Local Restriction/Route Dataset Inventory

This document lists files in this repository that appear to contain or relate to state truck restrictions (low clearances, weigh stations, restricted routes) and supporting loaders.

Found in this repo:

Data sources (JSON):
- data/state_restrictions.json
  - Canonical 50-state JSON container (currently includes NH/NJ samples). Expected shape:
    - { "<STATE>": { "lowClearances": string[], "weighStations": string[], "restrictedRoutes": string[] } }
  - Preferred input for the seeder.
- restrictions.json
  - Legacy/top-level JSON with the same schema (NH/NJ samples). Still supported by the seeder for backward compatibility.
- scripts/data/truck_restrictions.sample.json
  - Smaller sample dataset used for testing the seeder.

Seeder scripts:
- seed_truck_restrictions.mjs
  - ESM script. Reads data/state_restrictions.json (preferred) or restrictions.json fallback.
  - Upserts rows into the Supabase table truck_restrictions.
  - Optional geocoding when GEOCODE=1 and GOOGLE_MAPS_KEY is present.
- scripts/seed_truck_restrictions.js
  - Uses @supabase/supabase-js v2. Accepts a dataset path argument.
  - Upserts with onConflict: state_code,category,description.

Frontend usage:
- lib/features/route_planning/truck_restrictions.dart
  - Simple data model for restrictions.
- lib/features/route_planning/truck_restrictions_repository.dart
  - Repository to fetch restrictions from Supabase by state or bounding box (MVP client-side filter when lat/lng present).
- lib/features/route_planning/route_planning_screen.dart
  - _LiveRestrictionsPanel lists fetched restrictions per selected state.

Notes:
- No Excel (.xlsx) or standalone CSV/TXT datasets for restrictions were found in this repo at the time of indexing.
- CSV files present under supabase/seeds/phase4 are unrelated to truck restrictions (analytics, HOS, etc.).

How to use the dataset:
1) Add your full 50-state object to data/state_restrictions.json.
2) Ensure the Supabase table exists (see DDL in scripts/seed_truck_restrictions.js header).
3) Set env vars and run the seeder:
   - PowerShell (Windows):
     - $env:SUPABASE_URL = "https://<project>.supabase.co"
     - $env:SUPABASE_SERVICE_ROLE = "<service-role-key>"  # for seed_truck_restrictions.mjs
     - node seed_truck_restrictions.mjs
   - Or with scripts/seed_truck_restrictions.js (service key env var: SUPABASE_SERVICE_ROLE_KEY) and an explicit dataset path.
4) Optional: Add GEOCODE=1 and GOOGLE_MAPS_KEY to enrich geolocation points.

Updating this inventory:
- If you add new sources (e.g., low_clearances.xlsx, weighstations.csv, state_routes.txt), place them under data/ or docs/ and update this file accordingly.
