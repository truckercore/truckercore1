# Escalation Policy

Scope
- Applies to canary smoke failures, burn-rate alerts, deploy gate failures, and RLS/greenline leaks.

Severities
- Sev1: Burn-rate > 2.0 (1h) or > 1.0 (6h) for core features; deploy gate fail in prod; confirmed RLS leak.
- Sev2: Canary smoke fail in stage; burn-rate between 1.0–2.0 (1h) or 0.5–1.0 (6h); billing recon job failures.
- Sev3: Non-core feature burn-rate > 1.0; occasional canary flakes.

Escalation
- Sev1:
  - Page primary on-call immediately (24/7).
  - Auto-rollback if failure tied to recent deploy (last 2h).
  - Open incident channel + issue; post status within 15 min.
- Sev2:
  - Quiet hours (22:00–06:00 local): notify on-call via low-urgency (no page), page if persists > 30 min.
  - Business hours: Slack alert + ack; page if persists > 30 min.
- Sev3:
  - Slack alert to ops; triage during business hours.

Actions
- Canary fail (prod):
  - If new release: run Deploy Gate Rollback workflow; attach evidence artifact.
  - If not related to deploy: check burn-rate panel; throttle affected paths; file incident.

- Burn-rate alert:
  - Validate SLI panel and error logs; if sustained > 30 min at Sev1, enable feature flag fallback or degrade gracefully.
  - Create incident task to follow-up on root cause.

- RLS leak (greenline):
  - Call quarantine_table() for affected object; page Sev1; block RPC/view until fixed.

Quiet Hours
- 22:00–06:00 local timezone (team default). Only Sev1 pages immediately.

Postmortem
- Required for Sev1 within 3 business days; include SLI deltas, timelines, and corrective actions.
