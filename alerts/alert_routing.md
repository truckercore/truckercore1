# Alert Routing and On-Call

Routing
- Critical (SEV1/P0): page primary on-call immediately via paging system; escalate to secondary after 10 minutes if unacked.
- High (SEV2/P1): create triage ticket and page during business hours; auto-escalate if correlated with Critical health alerts.
- Medium (SEV3/P2): triage queue; no page; review within 24h.
- Low (SEV4/P3): backlog; review weekly.

Suppressions and Noise Control
- Mute recursive cascades during SEV1 remediation (5–10 min windows), but keep a heartbeat alert to detect total blind spots.
- Use correlation IDs to dedupe duplicate alerts across services.

Weekly Alert Review
- Every Monday 10:00 UTC: review alert performance (false positives, missed incidents), prune noisy rules, adjust thresholds.
- Track action items in shared backlog with owners and due dates.

Runbooks
- See runbooks/* for scenario-specific actions and comms templates.
