# Data Flows (Reviewer One‑Pager)

Scope: TruckerCore mobile/desktop apps (Driver, Owner‑Operator, Dispatcher, Broker)

What data flows
- Identity/session: email, org ID, plan tier → used to authorize features and personalize UI.
- Loads/dispatch data: loads, statuses, messages → stored in Supabase Postgres.
- Location (Driver): GPS points with seq + timestamp and optional activity → uploaded in batches when tracking is ON.
- Telemetry: crash/error traces and performance breadcrumbs → sent to Sentry when DSN configured.

Why it flows
- Core functionality: dispatch, routing, compliance, analytics.
- Safety and quality: detect crashes, improve performance; optional geofencing alerts.

Where it flows
- App → Supabase (tables, RPC/Edge Functions) in configured region.
- App → Sentry (telemetry) with tags {os, app_version, commit, plan_tier, locale}.
- Optional: App → Customer endpoints via webhooks (signed, idempotent) for events (load created/updated, assignment, docs).

Controls
- Feature flags gate tracking, geofences, chat, boosts by environment/plan.
- Driver controls: Start/Pause/Resume; persistent indicator while tracking.
- Privacy policy and terms URLs published in docs/policies/urls.json and public site.

Retention and correctness
- GPS raw positions: ~90 days (see docs/supabase/gps_p0.sql). Aggregates retain longer.
- Idempotency/order: device_id + seq; jitter/teleport filters applied server‑side.

Reviewer pointers
- See docs/reviewer/REVIEW_NOTES_IOS_ANDROID.md for step‑by‑step flows and screenshots to capture.
- See docs/policies/PRIVACY_POLICY.md and TERMS_EULA.md for legal text.
