# Windows CI Feedback Survey and Announcement

Use this lightweight survey to gather feedback from developers after the first wave of PR validations using the new Windows CI workflow.

## Announcement Template

Subject: Windows CI is live — faster diagnosis, clearer summaries

Hi team,

We’ve deployed the new Windows CI workflow with:
- Fail-fast runtime diagnostics
- Mocked-network integration tests for stability
- Enhanced smoke test summaries (HTTP status, elapsed ms, last error)
- Concurrency with auto-cancel of outdated PR runs
- Job summary includes queue time and total wall time

Docs:
- Monitoring guide: docs/ci/monitoring-pr-validations.md
- Troubleshooting: docs/ci/windows-ci.md

Please watch your next PR and let us know how it goes. Thanks!

## Short Survey (5 questions)

1) PR validation clarity
- How helpful were the smoke diagnostics (HTTP status, elapsed ms, last error) for identifying the failure?
  - Not helpful / Somewhat helpful / Helpful / Very helpful / N/A

2) Time saved
- Did the improved job summaries (queue time + wall time) save you time in understanding the pipeline behavior?
  - No / A little / Yes / A lot / N/A

3) False positives
- Did the CI fail for reasons unrelated to your code change (false positive)? If yes, please link the run and briefly describe.

4) Concurrency behavior
- When you pushed multiple commits quickly, did outdated runs get auto-cancelled as expected?
  - Yes / No / Not sure

5) Open feedback
- What part of the workflow or documentation should we improve next?

## Optional: Schedule a 15‑minute Review

- Purpose: Walk through a couple of PR runs, read job summaries together, collect immediate feedback.
- Attendees: Optional; devs who opened PRs in the last week.
- Materials: Have the Actions run Summary open, plus `docs/ci/monitoring-pr-validations.md`.
