# Continuous Security Assessment

Pentest Cadence
- External annual pentest and after major releases; scope: web, APIs, mobile, infra.
- Track findings in issue tracker with severity and SLA.

Monthly Reports (SCA/SAST/DAST)
- Generate monthly rollups from CI: npm audit (SCA), Semgrep/CodeQL (SAST), DAST template results when run.
- SLA tracking: Critical 24h, High 7d, Medium 30d, Low 90d. Exceptions require risk acceptance with expiration.

Chaos/Security Game Days
- Quarterly exercises to rotate webhook secrets, revoke keys, and simulate RLS misconfigurations.
- Verify monitoring/alerts capture issues and response meets MTTD/MTTR targets.

Metrics
- Vulnerability backlog by severity and age.
- Mean/median time to remediate by severity.
- Coverage of tests (authZ/RLS/webhooks/logging redaction).
