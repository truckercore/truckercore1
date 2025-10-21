# Tabletop Drills and Decision Trees

Scenarios and Decision Trees

1) Key/Secret Compromise
- Detect: alert from secret scanning, anomalous access, third-party report.
- Decide: revoke immediately? yes -> rotate keys (runbooks/key_compromise.md). no -> validate signal.
- Contain: disable affected endpoints, rotate creds, invalidate sessions.
- Communicate: internal <15m; customers if exposure likely.
- Verify: confirm new keys in rotation; enable additional detections.

2) Webhook Abuse/Replay
- Detect: spike in invalid/replay metrics, partner report.
- Decide: block offending endpoint? yes -> throttle/disable subscription. Investigate leaked secret.
- Contain: increase skew strictness, require idempotency, rotate secrets for affected subs.
- Communicate: notify partners; provide remediation guidance.
- Remediate: persistent replay cache; add rate limits; add tests.

3) Data Exfiltration Suspected
- Detect: unusual data export patterns, large query volumes, audit anomalies.
- Decide: freeze access for involved accounts/orgs? yes -> suspend tokens; preserve logs.
- Contain: narrow blast radius via RLS/policy changes; block suspicious IPs.
- Communicate: legal and exec loop-in; regulator prep.
- Forensics: timeline, access vectors, affected datasets.

4) Authentication Outage
- Detect: 5xx spike, auth latency/error SLO breached.
- Decide: rollback last change? yes -> rollback; else failover to standby.
- Contain: feature flag risky paths; reduce dependency pressure.
- Communicate: status updates every 30 minutes until resolved.

Drill Cadence
- Biannual red/blue drills with timed injects. Keep a scorecard:
  - Detection time, classification accuracy, comms latency, mitigation time, root-cause depth, action items created.
- Rotate IC, Comms, and Security Lead roles.

Artifacts
- Use POSTMORTEM_TEMPLATE.md post-drill.
- Track follow-up actions in a single backlog with owner and due date.
