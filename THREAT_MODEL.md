# Threat Model Template

Use this template at feature kickoff and update during development.

1. Feature overview
- Summary:
- Data handled (PII/PHI/financial/secrets):
- External dependencies (APIs, webhooks, storage):

2. Trust boundaries & data flows
- Diagram/link:
- Entry points (web/app/api/webhooks):

3. Assets & sec objectives
- Assets to protect:
- Goals: confidentiality, integrity, availability, non-repudiation.

4. Assumptions
- Environmental assumptions (TLS, authN provider, RLS):

5. Threats (STRIDE)
- Spoofing:
- Tampering:
- Repudiation:
- Information Disclosure:
- Denial of Service:
- Elevation of Privilege:

6. Controls & decisions
- Preventive:
- Detective:
- Corrective:
- Deferred/accepted risks (with issue links and review dates):

7. Test plan
- Unit/integration tests:
- Abuse/misuse tests:
- DAST scope:

8. Rollout & monitoring
- Metrics and alerts:
- Runbooks affected:
