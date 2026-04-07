# Runbook: Authentication Outage

1) Detection
- Spike in auth failures, 5xx on auth endpoints, or alert from monitoring.

2) Triage
- Identify scope (all users? specific orgs?).
- Check recent deploys, config changes, expired keys.

3) Mitigation
- Roll back recent changes if implicated.
- Fail open vs fail closed decisions documented; prefer fail safe.
- Communicate status to stakeholders.

4) Remediation
- Root cause analysis.
- Add tests/monitors to prevent recurrence.

5) Postmortem
- Use POSTMORTEM_TEMPLATE.md and track actions to completion.
