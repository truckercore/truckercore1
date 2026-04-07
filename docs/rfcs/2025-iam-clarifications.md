# IAM (SSO/SCIM) & JWKS Clarifications

Owner: @you  | Due: YYYY-MM-DD  | Applies to: SSO, SCIM, Admin

## JWKS / SSO Verifier
- JWKS cache TTL (min): ☐ 5  ☐ 15  ☐ 60  ☐ Other: ___
- Invalidate cache on: ☐ kid mismatch only ☐ any signature failure
- Rotation test plan: ☐ staged IdP change ☐ mocked JWKS endpoint

## IdP Health (traffic light rules)
- Red when cert expires in ≤ __ days
- Yellow when cert expires in ≤ __ days
- Fields: ☐ cert_expires_at ☐ last_success_sso_at ☐ groups_mapped ☐ drift_count

## SCIM
- First endpoints: ☐ Users:list ☐ Users:patch(deactivate) ☐ Groups:list
- Dry-run mode required? ☐ Yes ☐ No
- Bulk deactivate safety cap: ≤ __ users, confirm token scope: ☐ org-admin ☐ super-admin

## AI Ranking / Explainability
- Modules to log factors: ☐ loads ☐ parking ☐ promos ☐ roadside
- Required factors (top-5): ____, ____, ____, ____, ____
- Sampling: ☐ 100% ☐ 10% ☐ 1% ☐ per-tenant override

## Governance / Alerts
- Log config edits to audit with diff hashes? ☐ Yes ☐ No
- Who gets SAML expiry alerts? ☐ internal SRE ☐ customer admins ☐ both
