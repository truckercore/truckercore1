# HOS State Helpers

This migration adds:
- hos_logs_std: a normalized view that maps `on/off` to `on_duty/off_duty`.
- hos_compute_state(driver_uuid, at, cycle): a helper to compute current state with a pragmatic split‑sleeper pause and optional 34‑hour reset.

Status normalization
- Continue writing `hos_logs.status` with any of: off, sleeper, driving, on.
- Consumers should read from `public.hos_logs_std` which exposes `on_duty/off_duty` instead of `on/off`.

Split‑sleeper heuristic
- When a continuous `off_duty/sleeper` block of at least 7 hours ends at or before the query time, we treat the 14‑hour on‑duty clock as paused from the block start to end and set `effective_shift_start` to the end of that block.
- For full FMCSA 8/2 or 7/3 handling, extend the function to pair both qualifying segments and exclude driving/on‑duty time between them.

34‑hour reset
- If a continuous `off_duty/sleeper` block >= 34 hours exists since the last duty segment, `cycle_start` is set to that block’s end.

Indexes
- Existing: `idx_hos_driver_time(driver_user_id, start_time desc)`
- Added: `idx_hos_driver_time_status(driver_user_id, start_time desc, end_time desc, status)` which can help when querying at high frequency per driver.

RLS
- The underlying `hos_logs` table already has RLS. The `hos_logs_std` view is `security_invoker`, so caller’s RLS still applies if you expose the view to clients.
- Server functions or Edge jobs can call `hos_compute_state` unrestricted as needed via service role, or you can grant `authenticated` as in the migration.

Usage examples
- Current state (default cycle 70/8):
  - `select * from public.hos_compute_state('<driver_uuid>'::uuid);`
- At a specific timestamp and cycle:
  - `select * from public.hos_compute_state('<driver_uuid>'::uuid, now(), '70/8');`

Edge Functions to deploy (if used elsewhere)
- `health_info`
- `csv_preflight`
- `smoke_test_connectors`

Environment variables (per environment)
- `APP_ENV`, `APP_BUILD_SHA`, `STRIPE_MODE`
- `SUPABASE_URL`, `SUPABASE_ANON_KEY`, `SUPABASE_SERVICE_ROLE_KEY`
- Any partner feed keys used by fetchers

Mutating RPCs (reconcile, import, billing) — observability pattern
- At the top (optional): `select public.enforce_rate_limit('reconcile', 60, 5);`
- Wrap timing and log:
  - On success: `select public.log_fn_metric('reconcile','ok', duration_ms, ctx_json);`
  - On error: `select public.log_fn_metric('reconcile','error', duration_ms, ctx_json);`
- In EXCEPTION when `insufficient_privilege`:
  - `select public.log_rls_denial('','insufficient_privilege', ctx_json);`

Verification
- Normalize:
  - `select status, count(*) from public.hos_logs_std group by 1;`
- Compute state:
  - `select * from public.hos_compute_state('<driver_uuid>'::uuid);`
- Metrics views (existing):
  - `select * from public.v_fn_status_24h order by n desc;`
  - `select * from public.v_fn_p95_24h order by p95_ms desc;`
  - `select * from public.rls_denials order by at desc limit 20;`

Rate limits — exercise sensitive RPCs with a user session (JWT)
- Expect an HTTP 429 mapping in Edge when rate limit exceeded; include `Retry-After` header.