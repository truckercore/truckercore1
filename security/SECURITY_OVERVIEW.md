# Security Overview (v1)

## Architecture
- Clients (Web, Flutter) → Edge/API → Supabase Postgres → Storage/Queue
- Identity: SSO/OIDC with PKCE, nonce, state; SCIM-lite for provisioning
- Observability: structured logs, dashboards, alerting

## Data Flows
- Auth/session via OIDC; app JWT includes app_org_id and roles
- Promos/redemptions and operational updates
- Telemetry: privacy-by-design; coarse, time-bucketed where possible
- Operator updates; SSO/SCIM management

## Data Classification & Retention (summary)
- PII: user profile, auth — retain per legal; minimize scope
- Operational: promos, parking — retain 12–24 months aggregates
- Telemetry: coarse location — retain raw 14–30 days, aggregates 12–24 months
- Financial (escrow/invoices) — retain 7 years

## Security Controls
- RLS on all app data; least-privilege keys
- Encryption in transit/at rest
- Secrets management and rotation; scoped service roles
- Audit logging of sensitive operations
- Endpoint rate limits; abuse detection (self-check 429s)

## Compliance Roadmap
- SOC 2 readiness: change management, vendor risk, vuln mgmt cadence
- Incident response and runbooks

## Contact & Status
- Security contact: security@truckercore.example
- Status page: https://status.truckercore.example
- Coordinated disclosure policy: responsible disclosure supported
