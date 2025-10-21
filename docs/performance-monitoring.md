# Performance Monitoring Guide

## Table of Contents
1. Overview
2. Reading PR Comments
3. Per-Metric Thresholds
4. Handling Regressions
5. Optimization Guide
6. Justification Process
7. Baseline Management
8. FAQ

## Overview
This guide explains how we monitor performance in CI and in day-to-day development. It complements the Windows CI workflow and the Flutter baseline scripts. The goal is to quickly detect regressions, triage root cause, and make informed decisions to optimize or justify changes.

Key components:
- Flutter performance baseline with per-metric thresholds and PR summaries
- Clear triage flows for pub get, analyze, and test time regressions
- Standardized justification template and baseline update workflow

## Reading PR Comments
On PRs targeting main, the CI posts a Performance Baseline Comparison comment. It shows each metric (pub get, analyze, test, total), the baseline, the new value, percent change, and threshold.

Legend:
- 🟢 Improvement or within threshold
- 🟠 Slower but under threshold (not blocking)
- 🔴 Regression over threshold (blocking)

## Per-Metric Thresholds
Different metrics have different variance characteristics. Defaults can be overridden via env vars in CI.

| Metric | Threshold | Why |
|--------|-----------|-----|
| pub get | 15% | Network and cache variance |
| analyze | 10% | Deterministic, code-only changes |
| test | 20% | Test growth and mocking variance |
| total | 15% | Overall budget |

Environment variables:
- PERF_THRESH_PUBGET (percent)
- PERF_THRESH_ANALYZE (percent)
- PERF_THRESH_TEST (percent)
- PERF_THRESH_TOTAL (percent)
- PERF_REGRESSION_PCT (default for all, if specific not set)

## Handling Regressions
1) Assess Severity using percentage change and threshold.
- NONE: < threshold
- LOW: < 1.5x threshold
- MEDIUM: < 2.0x threshold
- HIGH: < 3.0x threshold
- CRITICAL: ≥ 3.0x threshold

2) Choose Response
- Optimize: Fix the cause and re-run CI
- Justify: Use the template below and rebaseline with approval
- Split: Separate performance-heavy part into follow-up

## Optimization Guide

### pub get Optimization
- Remove unused dependencies
- Use more specific version constraints (this repo uses ~ for minors)
- Consider lighter alternatives (@json2csv/plainjs instead of heavier wrapper)
- Check for conflicting versions via npm audit/outdated and overrides

### analyze Optimization
Add or confirm in analysis_options.yaml:
- analyzer.exclude: **/*.g.dart, **/*.freezed.dart, build/**, .dart_tool/**
- errors: todo: ignore, deprecated_member_use: warning

Investigate:
- flutter analyze --profile
- Ensure generated files are excluded
- Avoid enabling expensive or experimental lints globally

### test Optimization
- Mock all external services in integration tests (done via vitest setup)
- Use setUp/tearDown properly to prevent leaks
- Profile slow tests and parallelize where safe
- Tag or isolate particularly slow integration tests

## Justification Process
Use the following template in your PR when an intentional regression is acceptable.

### Justification Template

```
## Performance Impact

**Metric:** [pub get / analyze / test]
**Change:** [baseline] → [new value] (+X%)
**Threshold:** Y%

### Justification
[Why this change is necessary and acceptable]

### Mitigation
[What was done to minimize impact]

### Baseline Update
Updated in commit: [commit-hash]

### Approval
Discussed with: [@team-lead]
Risk accepted: [Yes/No]
```

Examples:
- "Added critical integration tests for payment flow (+25% test time)"
- "Included analytics SDK required by product (+18% pub get time)"
- "Refactored to improve type safety, increased analysis time (+12%)"

## Baseline Management

### When to Update
Update baseline when:
- Intentional features add dependencies
- Test coverage expansion is justified
- Architectural changes increase complexity

Do not update when:
- Regression is unexplained or unintentional
- Optimization is possible
- Impact is disproportionate

### How to Update
1) Verify locally
```
# On main
npm run perf:baseline > baseline-main.txt

# On PR branch
npm run perf:baseline > baseline-pr.txt

diff baseline-main.txt baseline-pr.txt
```
2) Document justification (template above)
3) Update baseline
```
# Run on PR branch
npm run perf:baseline
# Commit performance-baseline.md with a clear message
```
4) Get approval

## FAQ
- PR shows regression but no performance changes? Common causes: dependency updates, test count change, CI variance. Verify locally.
- Adjust thresholds? Yes—tune based on observed variance using environment variables.
- Temporarily skip gate? With approval, use a special PR title marker and follow-up fix.
- Test gate locally? Compare main vs feature outputs from `npm run perf:baseline`.
