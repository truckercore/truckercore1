# Runbook: Webhook Abuse / Replay Attacks

1) Detection
- Spike in webhook failures or suspicious duplicate deliveries.
- Anomalies in signature verification logs.

2) Triage
- Confirm signature failures vs replay blocks.
- Identify affected subscribers and endpoints.

3) Mitigation
- Throttle or temporarily disable offending subscriber endpoints.
- Rotate webhook secrets if suspected leak.
- Enforce strict timestamp skew and replay cache TTL.

4) Remediation
- Implement persistent replay cache (Redis/DB) and idempotency store with 409 semantics.
- Strengthen monitoring and dashboards for webhook metrics.

5) Communication
- Notify affected partners/subscribers with guidance.

6) Postmortem
- Document root cause; add tests; update detection/alerting.
