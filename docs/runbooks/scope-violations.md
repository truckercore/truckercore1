# Runbook: Scope Violations Spike

Triggered by alert: ScopeViolationSpike (403 forbidden_scope sustained)

1. Assess impact
- Check `scope_violation_total` by `route` and `required_scope`.
- Identify clients/orgs generating violations via logs.

2. Verify configuration
- Ensure route is documented with correct scope in OpenAPI and docs.
- Confirm recent changes to scopes or middleware wiring.

3. Mitigations (short-term)
- If business-critical, temporarily grant missing scope to affected key (with approval).
- Communicate required scopes to clients; provide examples.

4. Root cause & follow-ups
- Fix client integrations to request correct scopes.
- Adjust server-side scope names/mappings if misconfigured.
- Add more descriptive 403 messages or onboarding guidance.

Links:
- Alert: ScopeViolationSpike
- Dashboard: TruckerCore — API Phase 4 Routes