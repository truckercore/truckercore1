# Flutter Performance Gating and PR Feedback

This document explains how the automated Flutter performance baseline works in CI, how to interpret the PR comments, and how to rebaseline when needed.

## What runs in CI

On Windows CI for every PR targeting `main`:
- `npm run perf:baseline` collects timings for:
  - `flutter pub get`
  - `flutter analyze`
  - `flutter test`
- A new `performance-baseline.md` file is written in the workspace (and stored in the job as an artifact via logs).
- The current baseline is compared against `origin/main:performance-baseline.md` by `npm run perf:compare`.
- If any step or the Total time regresses by more than the threshold (default 10%), the job fails.
- A markdown summary is posted as a PR comment and appended to the GitHub Actions Job Summary.

## PR Comment Summary: How to read it

The comment includes a section like:

```
### Performance Baseline Comparison
- Threshold: 10% increase allowed
- 🟢 pub get: 12.10s (baseline 12.05s, change +0.4%)
- 🔴 test: 45.30s (baseline 38.00s, change +19.2%)
- 🟠 Total: 60.00s (baseline 55.00s, change +9.1%)
```

Legend:
- 🟢 Improvement (faster) or no significant change.
- 🟠 Slower but within threshold — not a blocker.
- 🔴 Regression exceeding threshold — this fails the job.

Notes:
- The threshold is configured via environment variable `PERF_REGRESSION_PCT` (default 10).
- If the baseline on main is an INITIAL PLACEHOLDER, gating is skipped until a real baseline is committed.

## Rebaselining (updating the ground truth)

Do this when:
- You made intentional changes that increase times but are acceptable, and the team agrees to update the baseline.
- You achieved improvements and want to lock them in as the new target.

Steps:
1) On a stable dev machine (or a dedicated runner), from the repo root run:
   - `npm run perf:baseline`
2) Review the generated `performance-baseline.md` for reasonableness.
3) Commit and push the updated `performance-baseline.md` to a branch and open a PR.
4) After approval, merge to `main`. Future PRs will compare against this new baseline.

Tips:
- Run the baseline when the machine is relatively idle to avoid noisy measurements.
- Keep hardware and environment as consistent as possible for comparability.

## Tuning the threshold

- Default threshold is 10% (configurable via `PERF_REGRESSION_PCT`).
- You can set a repository/organization Actions variable (e.g., `PERF_REGRESSION_PCT=15`) to relax or tighten sensitivity.
- Consider different thresholds per metric in a future iteration if needed (e.g., stricter for `analyze`, looser for `test`).

## Troubleshooting

- If CI says: "No baseline found on origin/main": commit a real `performance-baseline.md` to `main` following the Rebaselining steps.
- If `flutter` is not found on the runner/machine: ensure Flutter SDK is installed and in PATH for local runs. CI uses the measurement script only; it expects Flutter to be available on the runner if used outside GitHub-hosted images.
- If measurements are very noisy: re-run baseline; consider using a dedicated machine for consistent results.

## Communication and Notifications

- Announce the gate using the template in `docs/ci/ci-feedback-survey.md` and share the link to this doc.
- Consider wiring Slack/Teams notifications for failed performance gates using an Actions step (future enhancement).

# Performance Gating and PR Feedback

This document explains how the Flutter performance baseline gate works in CI and how to interpret the PR comments and job summaries.

## What the gate checks

- Runs `npm run perf:baseline` to generate `performance-baseline.md` with wall-clock times for:
  - pub get
  - analyze
  - test
  - Total (sum of the three)
- Compares the current PR’s numbers to the committed baseline on `main`.
- Fails the job if any step or the Total increases more than the threshold.

## Thresholds

- Default threshold is 10% (overridable via env): `PERF_REGRESSION_PCT=12`.
- Per-metric overrides (percent) are supported to reduce false positives:
  - `PERF_THRESH_PUBGET=15`
  - `PERF_THRESH_ANALYZE=10`
  - `PERF_THRESH_TEST=20`
  - `PERF_THRESH_TOTAL=12`

If a per-metric env var is not set, the default threshold applies.

## Rebaselining (when a slower change is intentional)

1. Ensure the slower change is justified (e.g., added critical tests or features). Add a short note in the PR description.
2. After merge, on `main` run:
   - `npm run perf:baseline`
   - Review `performance-baseline.md`
   - Commit the file with a message like: "perf: rebaseline after adding auth integration tests"
3. The comparison script will then use the new baseline for future PRs.

## Triage playbook (regression flagged)

- pub get:
  - Check recent dependency changes in `pubspec.yaml` and lockfile.
  - Verify cache effectiveness; retry to rule out transient network slowness.
- analyze:
  - Check added packages/generators; reduce analyzer scope if appropriate.
  - Fix hotspots (prefer `const`, avoid heavy rebuilds in large files if warnings point there).
- test:
  - Identify slow tests with `flutter test --reporter=expanded`.
  - Mock I/O-heavy paths; split very long tests or mark as integration.

## CI surfaces

- GitHub Actions PR comment: includes detailed comparison with % changes and thresholds.
- Job Summary:
  - Performance Baseline Comparison (with per-metric thresholds shown if set)
  - Windows CI Summary (queue time and wall time)
  - Smoke summaries (status, ms, last error)

## Notes

- The initial placeholder baseline on main disables the gate until replaced.
- Times are wall clock seconds as measured by Node, and may fluctuate slightly across machines. Use per-metric overrides if a particular step is noisy.
