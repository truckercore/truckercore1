# Data Classification & Handling Policy (Skeleton)

Purpose: Classify and protect data according to sensitivity.

Classes & Examples:
- Public: marketing site, public docs
- Internal: analytics aggregates
- Confidential: user PII, org configs
- Restricted: secrets/keys, credentials

Retention (summary):
- Telemetry raw 14–30d; aggregates 12–24m
- Audit logs 24m; invoices 7y

Controls:
- RLS on all app data; encryption in transit/at rest
- Access reviews for Confidential/Restricted classes

Evidence: retention configs, access logs, classification register.
