# SAML Assertion Validator Checklist (Draft)

Pass/Fail items to validate on ACS:

- Signature
  - [ ] Response/Assertion signature valid
  - [ ] Signed Assertions required; reject unsigned
  - [ ] Cert fingerprint matches stored IdP cert; metadata not expired

- Conditions
  - [ ] Audience matches SP entityID
  - [ ] Recipient matches allowed ACS URL
  - [ ] NotBefore/NotOnOrAfter within clock skew window
  - [ ] SubjectConfirmationData InResponseTo present for SP-initiated flows

- Attributes
  - [ ] Email present (attribute or NameID of emailAddress format)
  - [ ] Groups attribute present (optional) and parsed
  - [ ] Name present (optional)
  - [ ] Tenant/Org attribute present if required by policy

- Replay Protection
  - [ ] Track Assertion/Response IDs in a short-lived nonce store (e.g., 5–10 minutes TTL)

- Error Handling
  - [ ] Detailed error codes for invalid signature, audience mismatch, missing attributes, expired assertion, clock skew

Use the fixtures in `docs/saml/fixtures/` to test attribute extraction behaviors for common IdPs (Okta, Azure AD, ADFS).
