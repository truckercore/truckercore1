# SAML SSO Admin Guide (Draft v1)

This guide helps org administrators configure SAML SSO with TruckerCore.

1) Prerequisites
- Enterprise plan with SSO entitlement
- Your Org ID and admin access to both TruckerCore and your IdP

2) Service Provider (SP) Details
- Entity ID: `urn:truckercore:sp`
- ACS URL(s): `https://app.yourdomain.com/saml/{orgId}/acs`
- SP Certificate: upload PEM (public cert)
- SP Metadata: `https://app.yourdomain.com/saml/{orgId}/metadata`

3) IdP Setup (Okta / Azure AD / ADFS / Google)
- Create a SAML application in your IdP
- Configure ACS and Entity ID per above
- Sign Assertions (RSA-SHA256). Encrypted assertions optional
- Attributes required:
  - Email attribute (default key: `Email` or NameID emailAddress)
  - Groups attribute (default key: `Groups`)
  - Name attribute (default key: `Name`) optional
  - Optional Org attribute if you need tenant binding

4) Configure in Admin UI
- Navigate to Admin → SAML Settings
- Paste your IdP Metadata URL or upload XML (URL preferred)
- Enter ACS URLs, SP Entity ID (defaults provided), and SP Cert PEM
- Map IdP Groups → Roles in the Group Mapping section (coming next)
- Click Save, then Refresh IdP Metadata

5) Testing
- Use "View SP Metadata" to verify SP details
- For OIDC orgs, use the "Test SSO" button to run self-check (SAML-specific assertion simulation to be added)
- Pilot with 1–2 orgs before broad rollout

6) Troubleshooting
- Audience/Recipient mismatch: verify Entity ID and ACS exactly match
- Clock skew: adjust `clock_skew_seconds` (default 120s)
- Certificate expiration: refresh IdP metadata and rotate SP/IdP certs
- Error codes to log: `signature_failed`, `audience_mismatch`, `missing_email`, `expired_assertion`

7) Security Notes
- Signed Assertions required; reject unsigned
- Validate Audience, Recipient, NotBefore/NotOnOrAfter; enforce SubjectConfirmationData for SP-initiated
- Implement replay protection by storing Assertion/Response IDs briefly

8) SCIM (optional)
- SAML login works independently of SCIM provisioning. You can add SCIM later for lifecycle management.

Appendix
- Sample fixtures in `docs/saml/fixtures/` for assertion mapping
- Validator checklist in `docs/saml/validator_checklist.md`
