# RACI – Incident Response (Security and Availability)

Roles
- IC (Incident Commander): accountable for coordination and decisions.
- Comms Lead: prepares and sends communications (internal, customers, regulators).
- Ops Lead: leads technical mitigation and rollback.
- Security Lead: leads forensics, threat hunting, data risk assessment.
- Scribe: documents timeline, actions, and artifacts.
- On-call Engineer(s): implement fixes/mitigations.
- Product/Support: customer updates, status page coordination.

RACI by Activity
- Declare Incident: Responsible – On-call; Accountable – IC; Consulted – Security Lead, Ops Lead; Informed – Exec, Product.
- Severity Classification: R – IC, Security Lead; A – IC; C – Ops Lead; I – All stakeholders.
- Containment/Mitigation: R – Ops Lead, On-call; A – IC; C – Security Lead; I – Product/Support.
- Forensics/Root Cause: R – Security Lead, Ops Lead; A – IC; C – On-call; I – Product, Exec.
- External Comms: R – Comms Lead; A – IC; C – Legal, Product; I – Support.
- Regulator Notification: R – Comms Lead; A – Legal; C – Security Lead, IC; I – Exec.
- Postmortem & Action Items: R – Scribe; A – IC; C – Security Lead, Ops Lead; I – All.

MTTD/MTTR Targets
- Per severity in severity_matrix.md; IC measures and records actuals in postmortem.

Escalation Tree
- If IC not engaged within 10 minutes for SEV1/2, page secondary on-call and security on-call.
- Break-glass: if auth is down, follow auth_outage.md; if secrets compromised, follow key_compromise.md.
