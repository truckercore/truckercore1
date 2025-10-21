# Weekly Alert Review Process

Schedule
- Weekly, Monday 10:00 UTC, 30 minutes.

Attendees
- Security Lead, Ops Lead, On-call representative, ICs from recent incidents.

Agenda
- Review alerts triggered in the last 7 days: counts by rule and severity.
- Identify top noisy rules; propose suppression or threshold changes.
- Validate that SEV1/2 alerts paged appropriately and within targets.
- Ensure runbooks exist and are current for top alerts.
- Track action items with owners and due dates.

Outputs
- PRs to adjust alert thresholds/suppressions.
- Runbook updates.
- Backlog items for medium-term improvements.
