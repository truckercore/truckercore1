# Windows CI: Diagnostics, Tests, and Smoke

This workflow adds a Windows job that runs diagnostics, validates runtime prerequisites, runs tests with integration-network mocking, builds the web app, and executes simple smoke tests.

What it does:
- Runs scripts/windows/Check-Runtimes.ps1 to verify .NET and Visual C++ presence and basic repo permissions.
- Runs run-diagnostics.ps1 to reinstall dependencies and log dependency analysis.
- Runs unit tests and integration tests (integration tests are configured to mock external network calls unless REAL_NETWORK=1).
- Builds the Next.js web app and serves the static export for quick smoke probes.
- Probes a couple of key endpoints via scripts/smoke/smoke-web.mjs and scripts/smoke/smoke-api.mjs. The smoke scripts now report HTTP status, elapsed ms, and the last error message on failure to make triage faster.
- Runs flutter performance baseline collection (npm run perf:baseline) and compares it to the committed baseline on main; fails the job on >10% regression and posts a PR comment summary. See docs/performance/perf-gating.md for interpreting PR comments and rebaselining.

How to run locally:
- PowerShell (Windows):
  - powershell -ExecutionPolicy Bypass -File .\scripts\windows\Check-Runtimes.ps1
  - powershell -ExecutionPolicy Bypass -File .\run-diagnostics.ps1
  - npm run test:unit
  - npm run test:integration
  - npm run smoke:web

Tuning and troubleshooting:
- If you need real network calls in integration tests, set REAL_NETWORK=1.
- If diagnostics indicate missing runtimes, install latest .NET Runtime and Microsoft Visual C++ Redistributables for x86/x64.
- Review artifacts in the CI job for coverage and test-results.


## PR Validation Summary in GitHub Actions

On pull requests targeting main, this workflow now writes a concise summary to the PR job summary (GitHub Actions Step Summary):

- Windows CI Summary: includes ref, run attempt, concurrency group, queue time, and job wall time.
- Smoke Web Summary: lists each probed path with HTTP status, elapsed ms, and last error (if any).
- Smoke API Summary: lists probed API endpoints with the same diagnostics.

You can find this in the GitHub Actions run under the Summary tab. This makes it easy to spot regressions at a glance without digging through full logs.

## Monitoring and Metrics

- Use docs/ci/monitoring-pr-validations.md to guide the observation of early PR runs and detect false positives.
- Collect KPIs (success rate, average duration, average queue time) with:
  - Locally: `GH_TOKEN=ghp_xxx npm run ci:metrics`
  - In Actions: `npm run ci:metrics:summary`
- Concurrency is configured as `windows-ci-${ref}` with cancel-in-progress enabled; verify cancelled runs on rapid PR pushes.
