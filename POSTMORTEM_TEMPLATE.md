# Incident PM – <Title>
**Date/Window:** <YYYY-MM-DD HH:MM UTC to HH:MM>  
**Severity:** SEV-<1..4>  
**Owner:** <Name>

## Summary
One-liner explaining customer impact and duration.

## Impact
- % traffic / which tenants / which features
- Key SLOs breached (availability, p95)

## Timeline (UTC)
- T0 – First alert (key, channel)
- T+?m – Acknowledged by
- T+?m – Mitigation steps taken
- T+?m – Resolved

## Root Cause
- Primary cause, contributing factors, why it slipped past tests/alerts

## Mitigations & Follow-ups
- [ ] Test to catch this next time
- [ ] Alert or threshold change (what & where)
- [ ] Code fix (PR link), owner, due date
- [ ] Runbook update link

## Customer Communications
- Incident notice/blameless summary sent to: <list>


## Monitoring and Alerting Retrospective (Webhooks)

- Which webhook metrics and alerts fired? (webhook_verify_total, replay_total, webhook_secret_match_total, latency p95)
- Were thresholds effective or too noisy? Propose tuning or anomaly-based rules.
- Did dashboards surface the right views? Reference dashboards/webhooks_overview.json and note gaps.
- What new metrics/labels are needed?

## Provider/Dataset Version Drift Assessment

- Any provider_version_drift_total signals observed? Root cause and follow-ups with provider.

## Rotation and Key Provenance

- secret_version and key_id telemetry review; confirm rotation state and overlap efficacy.
