# CI Pipeline

The pipeline runs on each PR and on pushes to main:

1. Setup Flutter 3.35.1 (stable)
2. dart format . (fail if diff)
3. flutter analyze
4. flutter test --coverage
5. Coverage threshold check (scripts/coverage_check.dart, default 45% in CI)
6. Build smoke (web) for flavors: debug, release, staging, prod
7. Optional smoke API ping if FUNCTIONS_URL + SUPABASE_ANON_KEY are set in repo secrets

Fail-fast behavior:
- The analyze-test job must pass before build-matrix runs.
- The build matrix does not cancel other flavor builds on first failure to allow inspection; GitHub UI will still mark failure.

First failing line surfaced:
- Formatting step uses git diff to show changes.
- Analyzer and tests use default expanded reporters; the first failure appears directly in job logs.

Environment parity:
- If configs/{flavor}.env.json exists, it is applied via --dart-define-from-file for web builds.

Secrets required for smoke:
- SUPABASE_URL, SUPABASE_ANON_KEY (for build-time defines)
- FUNCTIONS_URL (Edge Functions base URL), optional

Local run (developer):
- dart format .
- flutter pub get
- flutter analyze
- flutter test --coverage
- dart run scripts/coverage_check.dart 0.40
- Build: flutter build web --release
