# SSO Setup Guide (OIDC + SAML)

## Prereqs
- Enterprise plan with SSO entitlement enabled.
- Org admin role (corp_admin) in TruckerCore.
- A test user in your Identity Provider (IdP).

---

## OIDC (Azure AD / Okta / Google)

### Redirect URIs
- https://app.truckercore.com/sso/callback
- https://{tenant}.truckercore.com/sso/callback (if vanity domains)

### Required scopes
- openid email profile

### Claims required
- email (or preferred_username), name, groups (custom claim), tenant/org attribute (optional)

### Configure IdP
- Azure AD: App registrations → Web → Redirect URIs; Token configuration → add groups or custom claim for groups.
- Okta: OIDC App → Assignments; add a Groups claim in the ID token.
- Google Workspace: OIDC → App URL and Authorized redirect URIs; use Directory API or custom claims for groups.

### App configuration
- issuer: https://login.microsoftonline.com/{tenant}/v2.0 (example)
- client_id: (from your IdP app)
- client_secret: (store securely)
- group_role_map (JSON):
  ```json
  { "TC-Corp-Admins":["corp_admin"], "TC-Dispatch":["dispatcher"] }
  ```

### Test
- In Admin, click “Test OIDC” (SSO Self‑Check). You should see discovery/JWKS checks, decoded claims (when available), and a role mapping result.

---

## SAML 2.0 (Okta / Azure AD / ADFS / Google SAML)

### Service Provider (SP)
- SP entityID: `urn:truckercore:{org_id}`
- ACS URLs:
  - `https://app.truckercore.com/saml/{org_id}/acs`
- Download SP Metadata from:
  - `https://app.truckercore.com/saml/{org_id}/metadata`

### Required attributes
- Email, Groups (multi‑value), Name, (optional) OrgId

### IdP configuration
- Upload SP metadata.
- Require signed Assertions.
- Digest/Sig Algorithm: SHA‑256 / RSA‑SHA256.

### Attribute Statements
- Email → user.email
- Groups → user.groups (multi‑value)
- Name → user.displayName

### Test
- In Admin, open SAML Settings → “Validate Assertion (Dry‑Run)” and paste a SAMLResponse (fixture). Verify extraction and role mapping preview.

### Troubleshooting
- Audience mismatch → confirm entityID matches exactly.
- Recipient mismatch → confirm ACS URL exactly.
- Clock skew → adjust in settings (±120s default).

---

## Tips & Security
- Map IdP groups to TruckerCore roles (corp_admin, regional_manager, location_manager, fleet_manager, dispatcher, safety, broker, driver). Many‑to‑many mapping is supported.
- JIT provisioning can create a user/org membership on first successful login when enabled.
- SCIM‑lite (optional) can synchronize create/update/deactivate and group‑based roles.
- OIDC security checks: iss/aud/exp/nonce/PKCE; JWKS rotation.
- SAML checks: signed assertions; audience/recipient; NotBefore/NotOnOrAfter; replay protection.
- Admin guardrails: self‑check, metadata refresh, certificate expiry warnings.
