# SSO & Role Catalog (Enterprise Readiness)

## Roles
- corp_admin, regional_manager, location_manager, fleet_manager, dispatcher, safety, broker, driver.

## OIDC/SAML Mapping
- Map IdP groups to roles (many-to-many). Store per-tenant mapping in DB (e.g., saml_group_role_map or a JSON group_role_map).
- JIT provisioning (optional): create user and org membership on first successful assertion/login.
- SCIM-lite (optional): Users (GET/POST/PATCH), Groups (GET/POST), map group changes to roles; deactivate via PATCH.

## Security Checks
- OIDC: Validate iss/aud/exp, verify nonce/PKCE, check JWKS kid and handle rotation.
- SAML: Require signed assertions; validate Audience (entityID) and Recipient (ACS URL); enforce NotBefore/NotOnOrAfter within clock skew; protect against replay.
- Admin guardrails: test metadata/assertion; certificate-expiry warnings; rate limits on self-check tools.

## Operational Notes
- Log SSO login start/success/fail with reason codes; surface success-rate and median login latency.
- Alert on failure rate spikes and canary drift; page on persistent canary failures.
- Document fallback admin bypass and rollback (see docs/SSO_ROLLBACK.md).
