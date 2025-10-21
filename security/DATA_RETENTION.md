# Data Classification & Retention Matrix (v1)

## Classes
- Public: marketing site content, public docs
- Internal: analytics aggregates, non-sensitive operational metrics
- Confidential: user PII, auth/session data, org configs, promo details
- Restricted: secrets/keys, credentials, tokens

## Retention
- Telemetry (raw gps_samples): 14–30 days; aggregates 12–24 months
- Promo/redemption events: 24 months (aggregated longer per contract)
- Audit logs (security/audit): 24 months minimum
- SCIM/SSO health logs: 12 months
- Financial/invoices: 7 years

## Access Controls
- RLS on all app data; org-scoped access
- Admin/service_role for privileged operations; approval workflow for elevated access
- Monitoring of access to Confidential/Restricted classes

## Backup/Restore
- Regular backups; periodic test restores
- Documented RTO/RPO targets

## Change Management
- Code reviews; CI/CD gates; production access controls
