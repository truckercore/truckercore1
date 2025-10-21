# Twilio Provider Profile

- Provider name: Twilio
- Versioning: X-Twilio-Signature header calculated over URL and params; when proxied into our system we normalize to HMAC v2.
- Required headers:
  - Signature: X-Twilio-Signature (base64); at edge, convert to x-truckercore-signature sha256=<hex>
  - Timestamp: provided via edge as x-truckercore-timestamp
- Timestamp formats: unix seconds
- Signature scheme: Our verifier uses v2 METHOD|path|ts|canonical body after normalization.
- Content types: application/json (for newer APIs); www-form-urlencoded for legacy only if allowlisted explicitly.
- IP allowlist: Twilio publishes IP ranges; document last review date and matched CIDRs.
- Tests: reuse core webhook tests; add adapter tests when native parsing is introduced.
