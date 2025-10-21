# Phase 3 — Enterprise Features (Mock First)

This step adds schema docs and client-side mocks for:
- Carrier/Broker Vetting Tools (safety/authority/insurance)
- Shipper Portal (role + load posting + market benchmarks)
- TMS/API Integrations (secure API layer + key management)

## Feature Flags (dev/stage)
Add as dart-define flags when running the Flutter app:

- FEATURE_PHASE3=true
- FEATURE_VETTING=true
- FEATURE_SHIPPER=true
- FEATURE_API_KEYS=true
- PHASE3_MOCK=true  (keeps all new endpoints in mock mode; no DB writes)

Example run:
```
flutter run -d chrome \
  --dart-define=FEATURE_PHASE3=true \
  --dart-define=FEATURE_VETTING=true \
  --dart-define=FEATURE_SHIPPER=true \
  --dart-define=FEATURE_API_KEYS=true \
  --dart-define=PHASE3_MOCK=true
```

## SQL Migrations (schema only; apply later for live)
- `docs/supabase/phase3_enterprise_features.sql`
  - `public.carrier_verifications` + indexes + RLS (readable by brokers; write by service role)
  - `public.shipper_loads` + indexes + RLS (shipper org, brokers see open, fleets/OO see assigned)
  - `public.api_keys` + RLS (org admins only)

Run in Supabase SQL editor or through CI pipeline when ready to go live.

## API & Mock Semantics (client-side services)
- Vetting (mock):
  - GET `/api/vetting/carrier/:dot_number` → returns deterministic payload by DOT suffix
    - Ends with 1 → valid (green)
    - Ends with 2 → expiring soon (yellow)
    - Ends with 3 → fraud flagged/unsat (red)
  - POST `/api/vetting/check` `{ dot_number }` → same payload (no DB writes)

- Shipper (mock):
  - POST `/api/shipper/loads` → stores in-memory for session; returns load
  - GET `/api/shipper/loads` → returns current user/org mock loads
  - GET `/api/shipper/market-rates?origin=...&dest=...` → proxies to existing mock Market Rates service

- API Keys (mock):
  - POST `/api/admin/api-keys` → generates a token once; stores masked in memory; returns full token only on creation
  - GET `/api/admin/api-keys` → returns masked keys with created/last_used/revoked
  - DELETE `/api/admin/api-keys/:id` → sets revoked=true
  - POST `/api/external/loads` with header `X-API-KEY: <token>` → 200 if valid and not revoked; 403 if revoked or unknown

## UI Placements
- Broker Dashboard: in load assignment area → “Verify Carrier” button (modal with color-coded vetting info)
- Fleet Manager Dashboard: same Verify Carrier modal when adding outside carrier
- Owner-Operator: “View my DOT/MC profile” under Compliance/Settings (stub)
- New Shipper Dashboard:
  - Left nav: My Loads, Post Load, Market Rates
  - Post Load form: origin/dest/equipment/dates/offered rate; inline market range hint
  - My Loads: table with status
- Broker Dashboard: new tab “Shipper Loads” → shows open shipper posts; Bid button (mock; disabled or displays toast)
- Admin Panel: “API Keys” tab for Brokers/Fleets/Shippers → Create/List/Revoke (mock); link to `/docs/api`
- `/docs/api`: mock Swagger-like overview of the 3 endpoints

## QA (mock)
- Carrier Vetting: DOT 1234561 (green), 1234562 (yellow), 1234563 (red)
- Shipper: Post a load → appears in My Loads and Broker’s Shipper Loads
- API Keys: Create → token visible once and masked in list; Revoke → 403 on external mock post

## Rollout Plan
1. Stage: enable internally with FEATURE_PHASE3=true, PHASE3_MOCK=true
2. Pilot: 1 shipper, 1 broker, 1 fleet admin; monitor usage
3. GA: Publish API docs and upsell as Enterprise tier; flip PHASE3_MOCK=false post-validation
