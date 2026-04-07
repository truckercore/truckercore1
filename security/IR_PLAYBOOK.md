# Incident Response (IR) Playbook (v1)

## Roles and Contacts
- On-call engineer
- Incident Response Lead (IRL)
- Communications Lead
- Legal / Data Protection Officer

## Severity Levels
- P0: Critical outage/security incident
- P1: Major degradation/security exposure
- P2: Minor impact
- P3: Informational

## Detection and Triage
- Alert sources: APM, logs, IDS, metrics (error rates, canary drift, SCIM failures)
- Initial assessment checklist: scope, blast radius, affected data/classes, current risk

## Containment and Eradication
- Disable keys/tokens; rotate secrets
- Block IPs/WAF; isolate components
- Toggle entitlements (e.g., disable SSO)
- Pause background jobs if needed

## Forensics and Evidence
- Preserve logs and timelines; snapshot relevant data
- Chain-of-custody notes

## Communication
- Internal updates cadence (e.g., every 30–60 minutes)
- Customer communications templates
- Regulator notifications when applicable

## Recovery
- RTO/RPO targets
- Step-by-step restoration; validation tests

## Post-incident
- RCA within 5 business days
- Action items with owners/dates; lessons learned

## Appendices
- OIDC/SAML security notes (PKCE, nonce, issuer/audience validation, JWKS rotation)
- SCIM security notes (bearer scope, IP allowlist optional, audit)
- Backup/restore process and testing cadence
- Change management: code reviews, CI/CD gates, production access controls
