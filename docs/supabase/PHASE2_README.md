# Phase 2 — Market Intelligence & Profit Tools

This folder contains SQL and notes to deploy Phase 2 backend components.

What’s included in this repo:
- SQL: `docs/supabase/phase2_market_intelligence.sql`
  - Tables: `market_rates`, `trihaul_suggestions`, `broker_credit_scores` (+ optional `credit_sources`)
  - Indexes and example RLS policies
- Client services:
  - `lib/features/pricing/market_rates_service.dart` — market lane rates (spot/contract + 90d series)
  - `lib/features/ai/trihaul_service.dart` — TriHaul suggest/accept via Edge Function (demo fallback)
  - `lib/features/pricing/credit_service.dart` — broker credit profile lookup (badge/filter support)
- UI stubs:
  - Broker Dashboard: Rate Insights panel + AI TriHaul panel
  - Fleet Manager Dashboard: Rate Insights panel
  - Loads List: Min Credit Score filter control (UI), ready to wire to server-side filtering

Edge Functions to implement server-side:
1) rates_refresh_job (daily @ 02:30)
   - Aggregates awarded rates from your org loads into `market_rates` with source = `tc_agg`
   - Accepts admin CSV for backfill of historical rates

2) trihaul_suggest (on-demand)
   - Input: { origin, dest, equipment, min_ppm, max_deadhead_mi, preferred_states? }
   - Uses `market_rates` + current loads inventory to propose top 3 options
   - Writes a row to `trihaul_suggestions` and returns { id, options }
   - Optionally publish realtime events/metrics `trihaul_requests`, `trihaul_latency_p95`

3) credit_refresh_job (daily)
   - Ingests CSV or partner API with { broker_id, score, days_to_pay, disputes }
   - Upserts into `broker_credit_scores`

API routes (if using Next.js/Edge Routes rather than direct Supabase RPC):
- GET `/api/rates?origin=ZIP&dest=ZIP&window=90d` — returns spot/contract latest + series
- POST `/api/trihaul/suggest` — calls `trihaul_suggest` function and returns 3 options
- POST `/api/trihaul/:id/accept` — sets `accepted=true`, returns deeplinks for each leg
- GET `/api/credit/broker/:id` — returns credit profile
- GET `/api/credit/search?min_score=NN` — server-side filtered list for job board

Gating (plan tiers):
- TriHaul = Premium for carriers/owner-ops/fleets; Broker gets in Pro+
- Market Rate Benchmarks = Pro+
- Credit Scores = Free badge; Pro for filters/details
- Use JWT claims (e.g., `plan_tier`) and/or org feature flags to enforce.

Performance targets:
- Rates API p95 ≤ 250 ms, payload < 50 KB
- TriHaul p95 ≤ 5 s (show loading + allow cancel)
- Job board with credit filters: p95 ≤ 400 ms (server-side pagination)

QA checklist highlights:
- Seed 90-day series for 10 lanes; verify sparkline and latest values
- TriHaul returns 3 options; at least 2/3 better than direct $/mi
- Accept plan sets `accepted=true` and deeplinks open expected filters
- Credit badge appears and min-score filter hides low-score posts when wired to server-side filtering
