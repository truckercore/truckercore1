# Runbook: Key/Secret Compromise

1) Detection
- Alert from monitoring, unusual access patterns, leaked key reported.

2) Containment
- Revoke/rotate affected keys immediately.
- Invalidate sessions/tokens if applicable.

3) Triage & Scope
- Identify systems and data potentially accessed.
- Review audit logs for suspicious activity.

4) Remediation
- Rotate all dependent keys; update configs; deploy.
- Improve secret storage, rotation cadence, and detection controls.

5) Communication
- Notify affected stakeholders and, if required, users.

6) Postmortem
- Use POSTMORTEM_TEMPLATE.md; track corrective actions.
