# Severity Matrix (SEV1–SEV4) and Targets

Severity Levels
- SEV1 (Critical/P0): Total auth outage, widespread data exfil suspected, production key compromise. RTO <= 1h. MTTD target: < 5 min. MTTR target: < 60 min.
- SEV2 (High/P1): Regional outage, webhook system degraded globally, elevated 5xx or RLS denials affecting many orgs. MTTD: < 10 min. MTTR: < 4 h.
- SEV3 (Medium/P2): Feature-specific outage/degradation, isolated tenant impact, elevated 4xx/validation or rate-limit anomalies. MTTD: < 60 min. MTTR: < 2 d.
- SEV4 (Low/P3): Minor bugs, noisy alerts, documentation/config drift. MTTD: < 1 d. MTTR: next sprint.

Classification Hints
- Impact scope: all users > multiple orgs > one org > subset of users.
- Data risk: confirmed exfil/PII exposure elevates to SEV1.
- Security signal: active exploit attempts + customer reports => raise one level.

SLO/Alert Linkage
- Alerts tagged sev:critical route to on-call immediately; high route to triage within business hours; medium/low create tickets.

Metrics Targets
- Auth endpoints: P95 < 300ms, error rate < 0.5%.
- Webhook verify: invalid/skew/replay < 0.5% of total; P95 verify < 50ms.
- Incident process: 100% postmortems for SEV1/2 within 5 business days.
