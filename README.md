# truckercore1

A new Flutter project.

## Environment Variable Update

See docs/MIGRATION_NOTES_SUPABASE_ANON.md for details on the new SUPABASE_ANON standard, legacy fallback behavior, and timeline.

## Pricing & Operator Analytics
- Pricing tiers overview: docs/pricing/pricing_tiers.md
- Operator Portal analytics dashboard layout: docs/operator_portal_analytics_dashboard.md

## Quick Checklist for New Contributors

- Review docs/MIGRATION_NOTES_SUPABASE_ANON.md (anon variable standard and deprecation).
- Copy .env.template to your local env file and fill values.
- Use Make targets or flutter run with --dart-define=SUPABASE_ANON=...
- Pre-commit guard:
  - Enable hooks: git config core.hooksPath .githooks
  - Ensure .githooks/pre-commit is executable (chmod +x .githooks/pre-commit)
- CI guardrails will fail new runtime references to SUPABASE_ANON_KEY (docs/env templates allowed).

## Flutter Build Quickstart (Windows)

Use the helper script to build the Flutter app artifacts locally (keeps everything related to .dart/Flutter in this project):

- Open PowerShell in project root and run:

```
powershell -ExecutionPolicy Bypass -File scripts\flutter_build.ps1
```

This will run: flutter clean, flutter pub get, flutter analyze, then build Android APK, Web, and Windows (if enabled). iOS builds require macOS.

Artifacts:
- Android APK: build\app\outputs\flutter-apk\app-release.apk
- Web static site: build\web
- Windows desktop: build\windows\runner\Release

Environment tips:
- For map tiles on the GPS screen, run with: `--dart-define=MAPBOX_TOKEN=pk.your_token`
- Supabase config is managed inside the app settings; ensure URL and anon key are set for data features.

### Find the first error in build_full.log (Windows PowerShell)
After running a verbose build like:

```
flutter build apk -v > build_full.log 2>&1
```

Run this one-liner to print the first error line:

```
Select-String -Path build_full.log -Pattern "^\s*e: |^\s*error: |A problem occurred|FAILURE: Build failed|\[   +\d+ ms\] Exception|Unhandled exception|cannot find symbol|NoSuchMethodError|Compilation failed" -CaseSensitive:$false | Select-Object -First 1 | % { $_.LineNumber.ToString() + ": " + $_.Line }
```

Alternatively, use the helper script we added:

```
pwsh -NoProfile -ExecutionPolicy Bypass -File scripts\first_error.ps1
```

## Setup & Versions

Toolchain versions locked for CI and local development:
- Flutter: 3.35.1 (Dart 3.9.0, DevTools 2.48.0)
- Android Gradle Plugin (AGP): 8.x (per android/gradle)
- Gradle: see android/gradle/wrapper/gradle-wrapper.properties
- Kotlin: per android/build.gradle (Kotlin plugin)
- Java: 17 recommended
- Node: 18 LTS (only if you work on Supabase Edge functions locally)

Install Flutter 3.35.1:
- Windows/macOS/Linux:
  - Follow https://docs.flutter.dev/get-started/install and then run:
    - flutter --version (confirm 3.35.1)
    - flutter doctor -v

Project setup:
- dart format .
- flutter pub get
- flutter analyze
- flutter test --coverage

Build flavors (web example):
- flutter build web --release --dart-define-from-file=configs/release.env.json
- For other flavors: configs/{debug|staging|prod}.env.json if present.

How to upgrade safely:
- Update Flutter via flutter upgrade to a pinned minor/patch, then update this README and docs/release/versions.md.
- Bump plugin/SDK versions cautiously and run CI. If build fails, revert or follow the rollback plan in CHANGELOG.md.

## Getting Started

This project is a starting point for a Flutter application.

### Running on Web (Chrome/Edge)
If your environment fails to auto-launch Chrome with an error like:

> Failed to launch browser after 3 tries. Command used to launch it: C:\\Program Files\\Google\\Chrome\\Application\\chrome.exe

You can run the app using the built-in web server device and open the URL manually:

```
flutter run -d web-server --web-port 52848 --web-hostname localhost
```

Then open http://localhost:52848 in your browser.

More tips are in scripts/web_server_launch.md.

A few resources to get you started if this is your first Flutter project:

- [Lab: Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Cookbook: Useful Flutter samples](https://docs.flutter.dev/cookbook)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.


## Troubleshooting: Steps 4–7 (Windows)

Follow these steps to quickly isolate build/runtime issues and prepare the final handoff.

### Step 4 — Confirm your environment (rules out toolchain issues)
Run the environment diagnostics helper:

```
pwsh -NoProfile -ExecutionPolicy Bypass -File scripts\env_doctor.ps1
```

What “good” looks like:
- flutter doctor -v shows no red errors for Flutter, Android toolchain, or Java.
- local.properties contains a valid sdk.dir path on your machine.
- Gradle shows it’s using Java 17 (look for “JVM:” or “Java version” lines with 17).

If any of these are wrong, fix them first (Android Studio Gradle JDK set to 17; JAVA_HOME points to JDK 17; Android SDK path valid).

### Step 5 — Isolate the first failing line
Capture a full verbose build log, then extract the first error:

Flutter path:
```
flutter build apk -v > build_full.log 2>&1
```
Gradle path (variant-specific, recommended when diagnosing signing):
```
cd android
./gradlew assembleDevDebug --stacktrace --info > ../gradle_build_full.log 2>&1
```
Or use the helper script from project root (Windows):
```
pwsh -NoProfile -ExecutionPolicy Bypass -File scripts\build_devdebug_gradle.ps1
```

Fast one-liner (from earlier section):

```
Select-String -Path build_full.log -Pattern "^\s*e: |^\s*error: |A problem occurred|FAILURE: Build failed|\[   +\d+ ms\] Exception|Unhandled exception|cannot find symbol|NoSuchMethodError|Compilation failed" -CaseSensitive:$false | Select-Object -First 1 | % { $_.LineNumber.ToString() + ": " + $_.Line }
```

Enhanced helper with fallbacks and optional context lines:

```
pwsh -NoProfile -ExecutionPolicy Bypass -File scripts\extract_first_error.ps1 -LogPath build_full.log -Context 5
```

Stop at the first occurrence that points to your app files (not framework or external packages).

### Step 6 — If logs look truncated, untruncate and re-run
- Ensure “show all output” is enabled in your IDE.
- Always redirect full output to build_full.log as above and re-run the extraction.
- If the error only appears for one flavor/variant, reproduce with that exact run configuration again.

### Step 7 — Provide the four items (final handoff)
Copy these back (with 1–3 lines of context around the error):

1) Exact error message:
```
<PASTE ERROR LINES>
```
2) File path + line number (or snippet shown in the stack):
```
<PATH and LINE or STACK SNIPPET>
```
3) Trigger (command/screen):
```
flutter build apk -v
```
4) Preferred fix style (choose one):
- Change parameter type
- toString coercion
- is-check with fallback
- explicit cast


### DevDebug end-to-end run (Steps 1–3 quickstart)

Use the helper to build the DevDebug variant with full logs and then run it:

```
pwsh -NoProfile -ExecutionPolicy Bypass -File scripts\run_dev_debug.ps1
```

- This writes the full verbose build output to build_full.log.
- If the build fails, the script automatically prints the first error using scripts\first_error.ps1.
- For deeper context, run:
```
pwsh -NoProfile -ExecutionPolicy Bypass -File scripts\extract_first_error.ps1 -LogPath build_full.log -Context 5
```

After the app launches on your device/emulator, navigate to:
- Pricing (route: /pricing)
- Bid Assist (open a load details screen that shows the Bid Assist button)
- HOS Manager (menu: Compliance > HOS Manager)

If any crash/red screen occurs, re-run the error extraction scripts above and keep the top-most failure.

Confirm environment parity (Java 17, Android SDK path, PATH shadowing) with:
```
pwsh -NoProfile -ExecutionPolicy Bypass -File scripts\env_doctor.ps1
```

On Windows, if Gradle fails mysteriously:
- Ensure the project path is short (e.g., C:\dev\truckercore1)
- Exclude build directories from antivirus/Defender
- Avoid spaces/Unicode in Android SDK and JDK paths

Gradle flavor/variant task for IDE builds: assembleDevDebug.

Signing for DevDebug:
- Debug builds use the default Android debug keystore automatically.
- Windows default path: %USERPROFILE%\.android\debug.keystore
- If missing, open Android Studio once and run a debug build, or create it via:
```
keytool -genkeypair -keystore "%USERPROFILE%\.android\debug.keystore" -storepass android -keypass android -alias androiddebugkey -keyalg RSA -keysize 2048 -validity 10000 -dname "CN=Android Debug,O=Android,C=US"
```
- Our Gradle config forces debug signing to use the default debug config; release signing remains separate and optional unless fully configured.



## Pre-submit & Merge Checklist (DevDebug)

- Rebase your branch on latest main and resolve conflicts.
- Push and wait for CI: all jobs must be green (Ubuntu build/analyze/tests and Windows env doctor, DevDebug build, analyze/tests).
- Artifacts sanity on Windows DevDebug job:
  - APK present with standardized name: app-devdebug--<YYYYMMDD_HHMMSS>-run-<RUN_NUMBER>.apk
  - build_full.log and first_error.txt (first_error should indicate no error-like lines on success)
  - build_scan.txt present and the URL shown in the job summary
  - Artifacts retained for 14 days
- Request review with summary: "DevDebug CI stabilized; standardized artifacts; first-error + build scan reports; retention set. Verified locally and on CI."
- Merge strategy: Prefer Squash merge. Ensure required checks are enforced on main.

## Runtime trap detection and CI guardrails (Steps 6–10)

### Step 6 — Runtime trap detection (if the build passes but something crashes)
- Start device/emulator log capture before reproducing the issue.
- Reproduce the crash/red screen, stop capture, and run:
```
pwsh -NoProfile -ExecutionPolicy Bypass -File scripts\first_error.ps1
```
- If nothing obvious, filter for common runtime failures:
```
Select-String -Path device_run.log -Pattern "Unhandled exception|type .* is not a subtype of" -CaseSensitive:$false | Select-Object -First 1
```
- For more context, use:
```
pwsh -NoProfile -ExecutionPolicy Bypass -File scripts\extract_first_error.ps1 -LogPath device_run.log -Context 5
```

### Step 7 — CI guardrails (prevent regressions)
Our GitHub Actions workflow includes Windows jobs that:
- Run env_doctor to verify environment (Java 17, Android SDK path, Gradle JDK 17).
- Build the DevDebug variant, save build_full.log as an artifact, and scan it using scripts/first_error.ps1 (job fails if any error is found).
- Run headless flutter analyze and a minimal widget test.
You can find it under .github/workflows/ci.yml.

Artifacts produced by the Windows DevDebug job:
- build_full.log (full verbose build output)
- first_error.txt (extracted first-error report; should state no error-like lines for signing)
- keystore_info.txt (path + SHA256 of debug.keystore; non-sensitive)
- DevDebug APKs: original and renamed app-devdebug--<YYYYMMDD_HHMMSS>-run-<RUN_NUMBER>.apk under build\\app\\outputs\\flutter-apk
- Build scan URL: shown in the CI job summary for quick access, and saved as build_scan.txt in artifacts

### Step 8 — Observability alignment
- The app sends an x-request-id header on Supabase requests. The client logs now echo the requestId on GET/POST start, completion, and error.
- Ensure your device log capture includes these requestId values so you can cross‑reference backend logs for Pricing/Bid/HOS API calls.

### Step 9 — What to send me if something breaks
Provide the following:
- First error block from scripts\first_error.ps1 (copy/paste), and whether it’s from build logs or device logs.
- The action that triggered it (build/run/specific screen).
- Your preferred fix style: change parameter type, coerce with toString, add is-check fallback, or explicit cast.

### Step 10 — If everything stays green
- Expand the run to a second build variant (e.g., Release or another flavor) and repeat Steps 1–6.
- Turn on a small cohort via feature flags for Pricing/Bid/HOS; monitor logs and metrics for a few days.
- If stable, widen the rollout.


## Supabase initialization (dev keys vs. no-supabase mode)

Also see: Seed Data Loader and Map Overlays (truck restrictions) below.

The app initializes Supabase before the UI starts if you provide URL and anon key via --dart-define. Example:

```
flutter run \
  --dart-define=SUPABASE_URL=https://your-project.supabase.co \
  --dart-define=SUPABASE_ANON=eyJhbGciOi...
```

Startup logs printed to your console will indicate the path taken:
- When initialized:
  - `[startup] Supabase.initialize → url=https://your-project.supabase.co`
  - `[startup] Supabase initialized OK`
- When not initialized (no-supabase mode):
  - `[startup] No Supabase initialization. Reason=useMockData=true` OR
  - `[startup] No Supabase initialization. Reason=missing SUPABASE_URL or SUPABASE_ANON`

Notes:
- After adding or changing Supabase.initialize, do a full restart of the app (not just hot reload). Close the running app and re-run flutter run so the SDK is initialized once at startup.
- In no-supabase mode the UI avoids direct Supabase access and certain panels gracefully no-op.
- You can also pass your keys when building:
```
flutter build apk \
  --dart-define=SUPABASE_URL=... \
  --dart-define=SUPABASE_ANON=...
```



## Enterprise Audit Logging (MVP)

What’s included:
- Tamper‑evident enterprise_audit_log with prev_hash and record_hash.
- Strict RLS: org‑scoped SELECT, no UPDATE/DELETE, inserts only via SECURITY DEFINER function fn_enterprise_audit_insert.
- Idempotent RPC example rpc_assign_driver with trace_id propagation.
- Feature flags seed: audit_logging, enterprise_hardening (supabase/migrations/02_feature_flags_seed.sql).
- Flutter Activity View (read-only): /admin/activity with filters, pagination, CSV export.
- Test scripts in scripts/: audit_helper.mjs, test_assign_driver.mjs, test_supabase_rpc.mjs (existing).

How to deploy migrations (Supabase CLI or SQL editor):
- Apply files in supabase/migrations/: 01_enterprise_audit_log.sql, 02_feature_flags_seed.sql (and existing migrations as needed).

Quick test of idempotent RPC (PowerShell):
```
$env:SUPABASE_URL = "https://<proj>.supabase.co"
$env:SUPABASE_ANON_KEY = "eyJhbGciOiJI..."
node scripts/test_assign_driver.mjs <ORG_UUID> <ACTOR_USER_UUID> <DRIVER_UUID> <LOAD_UUID>
```
Run twice; the second call should return {"status":"ok","idempotent":true}.

Log an audit record directly (service key recommended):
```
$env:SUPABASE_URL = "https://<proj>.supabase.co"
$env:SUPABASE_SERVICE_ROLE_KEY = "eyJhbGciOiJI..."
$env:ORG_ID = "<ORG_UUID>"
$env:ACTOR_USER_ID = "<USER_UUID>"
node scripts/audit_helper.mjs
```

Activity View in the app:
- Route: /admin/activity (requires Supabase initialized and RLS will scope by org_id from JWT).
- Filters: date range, user, action. Pagination 20/30/50 per page. Click download icon to export CSV via client-side generation.

Feature flags guidance:
- org_feature_flags zero-UUID row provides global defaults. Merge per-org overrides on server.
- audit_logging (bool): controls whether logAudit is invoked for sensitive writes.
- enterprise_hardening (bool): when ON, block legacy direct writes and require RPC/Edge. Enforce via backend middleware and DB grants.

Retention policy (plan):
- Enterprise ≥365 days; lower tiers ≥90 days.
- Add a weekly purge job later (pg_cron or external) to delete by created_at threshold per org tier.

Runbook (investigate suspicious activity):
1) Obtain trace_id from logs/UI.
2) DB recompute for a row: select public.fn_eal_verify_row('<AUDIT_ROW_ID>');
3) Verify prev_hash chain continuity for that org via order by created_at.
4) Export rows by org_id + trace_id and correlate with SIEM/gateway logs.

## Seed Data Loader and Map Overlays (Truck Restrictions)

Seed the truck_restrictions table from your 50-state JSON and render overlays in the app.

1) Create table and RPCs in Supabase (SQL editor):
- Open each file in schemas/ and execute:
  - schemas/truck_restrictions.sql
  - schemas/rpc_get_state_overlays.sql
  - schemas/rpc_route_hazards_simple.sql

2) Prepare your dataset:
- Preferred path: data/state_restrictions.json with shape:
  {
    "NH": {
      "lowClearances": ["US 1 Bypass — Portsmouth → 11’10”", "..."],
      "weighStations": ["I-89 NB, SB — Lebanon, west of exit 18", "..."],
      "restrictedRoutes": ["US 1 — Portsmouth, over Piscataqua River", "..."]
    },
    "NJ": { ... }
  }
- Legacy fallback also supported at restrictions.json (repo root).

3) Run the seeder (Node 18+):
- Option A (auto dataset path + optional geocoding):
  $env:SUPABASE_URL = "https://<proj>.supabase.co"
  $env:SUPABASE_SERVICE_ROLE = "<service-role-key>"
  # Optional geocoding
  # $env:GOOGLE_MAPS_KEY = "<maps key>"; $env:GEOCODE = "1"
  node .\seed_truck_restrictions.mjs

- Option B (explicit dataset path):
  $env:SUPABASE_URL = "https://<proj>.supabase.co"
  $env:SUPABASE_SERVICE_ROLE_KEY = "<service-role-key>"
  node .\scripts\seed_truck_restrictions.js data\state_restrictions.json

4) Map overlay in app:
- The TruckRestrictionsLayer and the Live Restrictions panel fetch by state via get_state_overlays RPC (fallback: direct table select).
- Categories:
  - low_clearance → red marker with LC label
  - weigh_station → blue marker with WS label
  - restricted_route → red marker (future: dashed polyline when geometry available)

5) Route compliance (RPC):
- Call route_hazards_simple from the app (already wired in TruckRestrictionsRepository.checkRouteHazardsSimple). It returns rows that intersect a route polyline bbox.

## Next.js frontend (App Router)

Local development (requires Node 18+):

1. Copy .env.example to .env.local and fill in values:
   - NEXT_PUBLIC_SUPABASE_URL
   - NEXT_PUBLIC_SUPABASE_ANON_KEY
   - NEXT_PUBLIC_BASE_URL=http://localhost:3000
2. Install deps:
   npm install
3. Start the dev server:
   npm run dev
4. Test the health/connection endpoint in another terminal:
   curl http://localhost:3000/api/health
   # Expected: { "status": "ok", "supabase": true|"env_missing"|"auth_err:..." }

Notes:
- A browser Supabase client is initialized at app/supabaseClient.ts using your Project URL and Anon Key.
- Tracking page is available at /track/[token] and fetches from /api/track/[token].
- For map preview on tracking, set NEXT_PUBLIC_MAPBOX_TOKEN in .env.local.



## API Testing: Postman Collections
Two ready-to-run Postman v2.1 collections with variables are included.

- R1 Consolidated: docs/postman/truckercore-R1-consolidated.postman_collection.json
- Weeks 4–5: docs/postman/TruckerCore-Week4-5.postman_collection.json
- Weeks 6–7: docs/postman/truckercore-weeks6-7.postman_collection.json
- Weeks 8–9: docs/postman/truckercore-weeks8-9.postman_collection.json
- Weeks 10–11: docs/postman/truckercore-weeks10-11.postman_collection.json
- Weeks 12–13: docs/postman/truckercore-weeks12-13.postman_collection.json
- Weeks 14–15: docs/postman/truckercore-weeks14-15.postman_collection.json
- Weeks 16–17: docs/postman/truckercore-weeks16-17.postman_collection.json
- Weeks 18–19: docs/postman/truckercore-weeks18-19.postman_collection.json

Variables inside the collections:
- baseUrl (e.g., http://localhost:3000 or your deployed API origin)
- token (Bearer JWT for protected endpoints)
- Other IDs like driver_user_id, broker_id, user_id, org_id, load_id, subject_id as applicable

How to use:
1. Open Postman → Import → Select the JSON file above.
2. Option A: Use the built-in collection variables as-is; Option B: Create a Postman Environment and move baseUrl/token there (recommended), then reference via {{variable}}.
3. Set baseUrl to your running API base (example: http://localhost:3000).
4. Set token to a valid JWT if your local API enforces auth.
5. Run individual requests or use the Collection Runner to execute all with tests (Weeks 6–7 collection has minimal/no tests by design).

Notes:
- Weeks 4–5 collection covers: ELD Provider A connect/webhook, HOS with violations, ETA v2 (P50/P80), Tri-haul suggest, Route optimize, Maintenance, Trust/Audit, Admin API keys/webhooks, Costs estimator, Offline tiles, CSV exports.
- Weeks 6–7 collection covers: ELD Provider B, Parking Suggest, Coaching Tasks, Insurance OCR, Offline Guarded Routing, Pricing Anomalies, Shipper Portal MVP, Auto-Assign, Onboarding Risk & Review, Compliance Summary.
- Responses align with the mock/demo endpoints implemented under app/api. Adjust baseUrl/token to match your environment.



## Release R1 (Weeks 12–19) — Consolidated Plan

Artifacts added for unified scope, backlog, and rollout:
- Consolidated backlog CSV (import into Jira/Linear): docs/truckercore-R1-consolidated.csv
- Preflight + Rollout Checklist (concise, actionable): docs/release/preflight-rollout-checklist.md
- Deployment Runbook (Stage → Prod): docs/release/deployment-runbook-stage-to-prod.md
- Cutover, QA, SRE, Security acceptance: docs/release/R1-cutover-qa-sre-security.md
- Feature flags and rollout gates: docs/flags/feature_flags_R1.md
- Unified OpenAPI (for contract tests and tagging by domain): docs/openapi/truckercore-openapi-all.yaml
- R1 OpenAPI Index (aggregator for per-domain specs): docs/openapi/truckercore-R1-index.yaml

How to use:
- Backlog: Import the CSV into Jira/Linear. After import, you can prune/split by team; dependencies are preserved in the “Depends On” column.
- Preflight: Work top-to-bottom through docs/release/preflight-rollout-checklist.md prior to stage/prod cutover.
- Flags: Toggle per-org via your feature flag store. Keep production OFF by default and enable per the cutover phases.
- QA: Use the existing Postman collections in docs/postman along with the unified OpenAPI for contract tests.



## CI and PR gates\n\n- Workflow: .github/workflows/flutter_ci.yml runs analyze_and_test on pushes/PRs to main.\n- Caching: The workflow caches the Flutter SDK (via action), Pub packages (~/.pub-cache), and Gradle (~/.gradle) to speed up CI.\n- Optional e2e: integration_tests job boots a headless Android emulator and runs integration_test/* if present. You can disable this job in branch protection or keep it informational.\n- Protection rules: In GitHub → Settings → Branches → Branch protection rules, require the analyze_and_test job (and integration_tests if desired) to pass before merging to main.\n\n## Supabase 1.x client migration notes\n\nThe codebase is migrated to Supabase Dart v2 (postgrest v1.x) positional filter APIs. Key points for contributors:\n- Use positional args for filters: .eq('col', val), .ilike('col', '%q%'), .neq/gt/gte/lt/lte/is/contains/like/ilike all take positional column first.\n- Remove legacy v2_compat shims and any postgrest direct imports; rely on supabase_flutter.\n- Don’t pass columns: '*' to select() unless needed — select() defaults are fine in most places.\n- Prefer maybeSingle() when zero-or-one rows are expected.\n- Keep RLS policies in sync with new tables; run docs/supabase RLS checks or use public.self_test_rls().\n\nIf you encounter legacy code with named filter arguments (column: ..., match: ...), convert to positional as above.\n\n## Supabase quickstart (adapter)

This repo now includes lib/supabase_config.dart for simple apps or samples that expect a SupabaseConfig with url and anonKey.
It reads SUPABASE_URL and SUPABASE_ANON (or legacy SUPABASE_ANON_KEY) from --dart-define and falls back to the existing AppEnv values.

Run examples:

```
flutter run \
  --dart-define=SUPABASE_URL=https://your-project.supabase.co \
  --dart-define=SUPABASE_ANON=eyJhbGciOi...
```

Verification checklist:
- SUPABASE_URL points to https://<proj>.supabase.co
- SUPABASE_ANON uses the anon public key (not service key)
- Supabase.initialize happens before runApp (already handled in main.dart)
- If connected but data seems empty, review your RLS policies.

Troubleshooting:
- 401 Unauthorized -> check RLS and that the anon key is correct (Project Settings → API)
- Failed host lookup -> verify SUPABASE_URL and network connectivity




## Backend health probe and banner (Supabase)

This repo includes a lightweight health probe and optional warning banner you can drop into any screen.

- Env adapter: import 'lib/env.dart' to access Env.supabaseUrl / Env.supabaseAnonKey, which delegate to SupabaseConfig/AppEnv and prefer --dart-define.
- Health probe helper and banner live at lib/core/supabase/backend_banner.dart.

Example usage:

```dart
import 'package:flutter/material.dart';
import 'package:truckercore1/core/supabase/backend_banner.dart';

class SomeScreen extends StatelessWidget {
  const SomeScreen({super.key});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Some screen')),
      body: Column(
        children: const [
          BackendBanner(), // shown only if health probe fails
          Expanded(child: Center(child: Text('Content'))),
        ],
      ),
    );
  }
}
```

Ping the backend manually:

```
final status = await pingBackend(); // returns 'ok (N)' or 'error: ...'
```

SQL for the health table and related audit/backoff aids is available at:
- docs/supabase/health_and_escalation.sql

An Edge Function skeleton for the retest backoff loop is available at:
- functions/retest-backoff/index.ts (Deno)

Notes
- Supabase is initialized in main.dart before the UI starts when SUPABASE_URL and SUPABASE_ANON are provided.
- In mock/no-supabase mode, avoid using BackendBanner (it will show an error because the table is unreachable).



## Supabase: Org indexes, idempotent escalation insert, and quarterly effectiveness (nightly)

This repo includes SQL and an Edge Function to support high‑traffic, org‑scoped analytics and safe escalation inserts.

Apply SQL (via Supabase SQL editor or CLI):
- docs/supabase/org_indexes_and_idempotent_escalation.sql
  - Adds key org/date indexes (alerts_events, escalation_logs, retest_runs, remediation_clicks, sso_health, scim_audit, metrics_events, analytics_snapshots).
  - Adds idempotency columns and unique index on escalation_logs, tenant insert policy, and RPC fn_escalation_insert_idempotent.
- docs/supabase/quarterly_effectiveness_materialization.sql
  - Creates v_alert_effectiveness_qtr (logical view), alert_effectiveness_qtr_mat (materialized storage), and RPC fn_refresh_alert_effectiveness_qtr_mat.

Edge Function (for nightly refresh):
- functions/refresh_quarterly_effectiveness/index.ts
  - Calls fn_refresh_alert_effectiveness_qtr_mat and returns { ok, rows }.
  - Reads SUPABASE_URL and SUPABASE_SERVICE_ROLE (or SUPABASE_SERVICE_ROLE_KEY) from env.

Schedule (Supabase):
- Settings → Scheduled triggers → HTTP request → Invoke the refresh_quarterly_effectiveness function daily (e.g., 02:10 UTC).

Notes:
- All SQL is idempotent (create if not exists / create or replace).
- Ensure your JWT contains app_org_id for org‑scoped RLS to work with escalation_logs.



## Governance & Branch Protection

Required status checks on main:
- Flutter CI / analyze_and_test (analyze + tests)
- Runbooks Validation / runbooks_check
- Node Audit / node_audit
- Optional: Flutter CI / integration_tests

How to enable:
- In GitHub → Settings → Branches → Branch protection rules → Protect main and require the checks above. Alternatively, run the workflow: .github/workflows/branch_protection.yml with a repo/org secret ADMIN_TOKEN that has admin permissions; it will configure protection automatically.

Automatic governance labeling:
- .github/workflows/auto_label_governance.yml + .github/labeler-governance.yml label PRs touching runbooks/**, docs/**, **/*.sql, .github/**, or scripts/ci/** with the governance label. You can map this label to auto-assign reviewers in Repo Settings → Code review → Auto-assignment.

Weekly Ops note:
- .github/workflows/weekly_ops_note.yml runs weekly and opens/updates an issue titled "Weekly Ops Note – YYYY-MM-DD" summarizing:
  - p95/availability breaches (from public.slo_burn_7d)
  - Recent Runbooks CI failures
  - RLS audit disabled tables count (from public.rls_audit)
- Requires SUPABASE_DB_URL in repo secrets to pull DB metrics; if absent, it will still produce a note with CI data.

Quarterly/Monthly reviews:
- Quarterly Dependency Review: .github/workflows/quarterly-deps-review.yml (Flutter/Dart/Node).
- Monthly Deprecation Review: .github/workflows/deprecation_review.yml (optional analyzer warnings & outdated).

Security & Ops checks:
- Node Audit: .github/workflows/node_audit.yml fails on high/critical prod vulnerabilities and uploads audit.json.
- Runbooks Validation: .github/workflows/runbooks_check.yml verifies runbooks/*.md has title and core sections (Summary, Monitoring, Rollback).


## Webhooks Security & Ops Resources

- Security policy: SECURITY.md (includes Webhooks Security Summary)
- Partner onboarding: docs/partners/webhooks_onboarding.md
- Provider profiles: docs/providers/
- SLOs: docs/SLOs.md (Webhooks Verification SLOs)
- Dashboards: dashboards/webhooks_overview.json (Grafana)
- Alerts: alerts/slo_thresholds.yaml and alerts/anomaly/
- Chaos drills (staging, dry-run by default): chaos/drills/
- Automated red-team: tooling/redteam/webhook_rt.mjs
- PIR checklist: ops/PIR_CHECKLIST.md
