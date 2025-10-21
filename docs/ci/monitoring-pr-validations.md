# Monitoring Initial PR Validation Runs

This guide explains how to actively observe the first wave of pull requests running through the Windows CI workflow and how to tune the system based on findings.

## What to watch for

- False positives:
  - Validate that workflow failures correlate to a real issue in the code change.
  - If the workflow fails due to environmental checks (runtime diagnostics) on a valid change, capture the failure details and consider relaxing/tuning the checks.
- Concurrency behavior:
  - Outdated runs should be auto-cancelled when new commits are pushed to the same PR.
  - Verify in the job Summary the "Concurrency group" and that older runs are cancelled in the PR Checks UI.
- Diagnostic usefulness:
  - Smoke summaries include HTTP status, elapsed ms, and last error for each endpoint.
  - The job summary now also shows queue time and wall time, helping distinguish waiting vs. executing.

## Where to look (fast path)

- GitHub Actions > PR run > Summary tab:
  - "Windows CI Summary" contains ref, attempt, concurrency group, queue time, and job wall time.
  - "Smoke Web Summary" lists GET / and /api/metrics results with status/ms/error.
  - "Smoke API Summary" (if used) lists API endpoints similarly.
- Artifacts:
  - coverage/ and test-results/ are uploaded even on failure (best-effort).

## Verify concurrency

- The workflow has a concurrency group: `windows-ci-${ref}` and `cancel-in-progress: true`.
- Push multiple commits quickly to the same PR and verify older runs show "Cancelled".
- In the job summary, confirm the group matches the PR ref.

## Identify false positives

1. Use the Summary diagnostics to determine which phase failed.
2. If failure is in the diagnostics step (runtimes), validate on a separate Windows machine:
   - Run: `powershell -ExecutionPolicy Bypass -File .\scripts\windows\Check-Runtimes.ps1`
   - Repair runtimes if missing (Visual C++ Redistributables, .NET Runtime).
3. If failure is in smoke tests:
   - Re-run locally: `npm run build:web && npm run smoke:web`
   - Investigate endpoint logs or Next.js build warnings.
4. If failure is not reproducible locally, consider runner flakiness; re-run the job and compare.

## Track KPIs (duration, queue time, success rate)

Use the included metrics script to capture a baseline for early runs and to watch for regressions.

- Local usage:
  - `GH_TOKEN=ghp_xxx npm run ci:metrics`  (or set `GITHUB_REPOSITORY`)
- In Actions (inside a job):
  - `npm run ci:metrics:summary` (uses the default GITHUB_TOKEN and writes to the job summary)

Metrics reported:
- Success rate across recent completed runs
- Average job duration
- Average queue time

Adjust the sample size with `--limit`.

## Tuning based on findings

- Reduce flakiness:
  - Favor mocked integration tests in CI; keep E2E smoke minimal/deterministic.
  - Increase `testTimeout` or reduce threads if contention is observed.
- Speed up builds:
  - Ensure dependency caching is effective (actions/setup-node cache: npm).
  - Consider splitting tests and build into parallel jobs if queue time dominates.
- Runtimes:
  - If diagnostics are too strict, convert some warnings to non-blocking messages.

## Communicate and gather feedback

- Announce in chat/email using the template in `docs/ci/ci-feedback-survey.md`.
- Run the short survey after a few PRs to measure usefulness of diagnostics.
- Host a 15-minute optional review session to walk through logs and outcomes.
