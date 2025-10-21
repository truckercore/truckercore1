# Provider Communication Process

Purpose: Ensure timely intake and handling of provider webhook changes and security updates.

1. Subscriptions and Watch Lists
- Subscribe engineering@ to provider status/security mailing lists.
- Monitor RSS/Changelog pages for Stripe, GitHub, Slack, Twilio monthly.
- Assign owner(s) per provider.

2. Intake Workflow
- Log each announcement/change as a ticket with links and proposed impact.
- Map changes to our Provider Profile and tests; update allowed versions and header expectations if needed.
- Identify rollout timeline and deprecation windows.

3. Validation Checklist
- Update docs/providers/<PROVIDER>.md.
- Add/adjust tests for version/headers/content-type if format changed.
- Run red-team pipeline to ensure no regressions (cross-endpoint replay/downgrade).
- Verify dashboards/alerts reflect new metrics if any.

4. Rollout
- Stage changes behind feature flags.
- Canary with a small subset of endpoints/orgs.
- Monitor dashboards (invalid rate, next secret match, latency) for 24–48h.

5. Communication Back
- Confirm with provider support if behavior deviates from docs.
- Document outcomes in the Provider Profile change log with date/owner.
