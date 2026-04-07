# Evidence Chain of Custody

| Export File              | Control Objective                  | Source View/Table                | Owner    |
|--------------------------|------------------------------------|----------------------------------|----------|
| audit_log.csv            | CC7.2 Change Management            | public.audit_log                 | SecOps   |
| entitlements.csv         | CC6.1 Access Provisioning          | public.entitlements              | Platform |
| alerts_events.csv        | CC7.3 Monitoring & Alerting        | public.alerts_events             | SRE      |
| backups_manifest.csv     | A1.2 Backup & Recovery             | ops.backups_manifest             | DevOps   |

Notes:
- All evidence bundles are archived with SHA-256 manifest and optional GPG detached signature.
- S3 uploads use SSE and Object Lock Governance with a default retention of 90 days (configurable).
- See scripts/evidence_snapshot.sh for implementation details.
