# Flip to Live — Phase 2 + Phase 3 (Flutter + Supabase)

This runbook explains how to flip Phase 2 (Market Rates, TriHaul, Broker Credit) and Phase 3 (Carrier Vetting, Shipper Portal, API Keys) from mock mode to live in the TruckerCore Flutter app backed by Supabase.

Prereqs
- Code deployed on the target environment (stage first, then prod)
- Supabase project URL + anon/service keys configured in runtime
- Database backup available (Supabase → Backups → Create backup now)

Flags (environment)
- PHASE2_MOCK=false
- PHASE3_MOCK=false
- FEATURE_MARKET_RATES=true
- FEATURE_TRIHAUL=true
- FEATURE_BROKER_CREDIT=true
- FEATURE_VETTING=true
- FEATURE_SHIPPER=true
- FEATURE_API_KEYS=true

Migrations — Apply in Stage, then Prod
Run these SQL files in Supabase SQL Editor or CI:
- docs/supabase/phase2_market_intelligence.sql
  - Tables: public.market_rates, public.trihaul_suggestions, public.broker_credit_scores (+ credit_sources)
  - Indexes + RLS examples
- docs/supabase/phase3_enterprise_features.sql
  - Tables: public.carrier_verifications, public.shipper_loads, public.api_keys
  - Indexes + RLS policies
- (Phase 1, if not applied) docs/supabase/phase1_saved_searches_alerts.sql
- (Combo roles) docs/supabase/phase1_combo_roles.sql

Verification SQL (run after)
- select to_regclass('public.market_rates');
- select to_regclass('public.trihaul_suggestions');
- select to_regclass('public.broker_credit_scores');
- select to_regclass('public.carrier_verifications');
- select to_regclass('public.shipper_loads');
- select to_regclass('public.api_keys');
- select relname, relrowsecurity from pg_class where relname in ('market_rates','trihaul_suggestions','broker_credit_scores','carrier_verifications','shipper_loads','api_keys');

Schedulers (optional now)
- rates_refresh_job daily 02:30 (disabled until comfortable)
- credit_refresh_job daily 02:45

Stage Flip Steps
1) Post an in-app banner: “We’re applying data upgrades. Live features may refresh.” (soft freeze)
2) Apply migrations above on stage
3) Set flags to live on stage (see Flags).
4) Warm endpoints (first calls can be cold):
   - Market Rates: load a lane in Broker/Fleet Rate Insights panel
   - TriHaul: open panel and request suggestions
   - Credit: open Loads list (Badge detail will query credit profile)
   - Vetting: open Verify Carrier sheet and check DOT 1234567
   - Shipper: open /dashboard/shipper and post one load
   - API Keys: open /admin/api-keys and create/revoke a key
5) Smoke test (expect empty/”no data” until you insert test rows):
   - Market Rates: insert one public row:
     insert into public.market_rates (org_id, origin_geo, dest_geo, lane_key, spot_rate_usd_per_mi, contract_rate_usd_per_mi, sample_size, source, collected_at)
     values (null, '{"zip":"30301","state":"GA"}', '{"zip":"75201","state":"TX"}', '30301->75201', 2.25, 2.00, 184, 'manual_upload', now());
   - Credit: insert one broker score:
     insert into public.broker_credit_scores (broker_id, score, days_to_pay_avg, disputes_90d)
     values ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', 86, 26, 1);
   - Vetting: insert one carrier verification row:
     insert into public.carrier_verifications (org_id, dot_number, mc_number, insurance_provider, insurance_expiry, safety_rating, fraud_flag)
     values ('11111111-1111-1111-1111-111111111111','1234567','MC999999','Acme','2026-01-31','satisfactory',false);

Acceptance targets (p95)
- Rates ≤ 250 ms, TriHaul ≤ 5 s, Credit ≤ 150 ms
- Error mapping: 400 validation, 403 gating/upsell, 404 feature off; no 500s

Prod Flip
1) Backup DB
2) Toggle flags in prod runtime: PHASE2_MOCK=false, PHASE3_MOCK=false (keep FEATURE_* true)
3) Warm endpoints by opening panels once
4) Monitor for first 60 min
   - Latency p95, error codes, 500 spikes (none expected)
5) (Optional) enable schedulers (rates/credit refresh jobs) when comfortable
6) Remove banner: “Upgrade complete. Live intelligence, vetting, shipper portal, and API keys are active.”

Rollback
- Flags first: set PHASE2_MOCK=true and/or PHASE3_MOCK=true. UI remains functional with mock data
- Pause schedulers if needed
- Restore snapshot only if data corruption occurs (rare)

Notes for Flutter implementation
- Providers already dual-path via phase2_flags.dart and phase3_flags.dart
- Live branches read Supabase; org_id scoping enforced by RLS; app never trusts client org_id
- UI shows a small “Demo data” chip in Rate Insights & TriHaul ONLY when mock is on; chips disappear when flipped to live
- Owner-Operator Heatmap overlay restricted to Owner-Op role

QA Checklist
- Stage:
  - /api/rates path via panel returns live row for 30301->75201
  - TriHaul returns 3 options (or graceful “no matches” if inventory absent)
  - Credit endpoint (badge/detail) returns live row for inserted broker id
  - Vetting modal resolves DOT 1234567 from table
  - Shipper Portal can post and list a load
  - API Keys can create & revoke (live path may be implemented later; mock path remains harmless)
- Role-by-role smoke matches the PR description
- Toggling PHASE2_MOCK/PHASE3_MOCK back to true restores mock responses
