# SSO/SCIM Health Runbook

Owner: SRE | Last updated: YYYY-MM-DD

- Self-check: run admin “Re-test” (rate-limited)
- Canary drift: investigate issuer/JWKS; rotate if needed
- SCIM failures: run dry-run diff; check token scope; retry with safety cap
- Rollback: disable SSO, rotate secrets, revert group mappings
- RTO/RPO: RTO 4h, RPO 24h — restore steps linked in Ops runbook
