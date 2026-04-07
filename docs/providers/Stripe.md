# Stripe-style Provider Profile

- Provider name: Stripe (style)
- Versioning: Stripe-Signature header includes timestamp; events carry an API version.
- Required headers:
  - Signature: Stripe-Signature (we map to verification expectations internally)
  - Timestamp: from signature header or x-truckercore-timestamp when proxied
- Timestamp formats: unix seconds recommended.
- Signature scheme: HMAC-SHA256; our verifier uses v2 METHOD|path|ts|body canonicalization when integrated via our edge.
- Content types: application/json
- IP allowlist: Stripe publishes IP ranges; document last review date.
- Tests: link to tests/webhook_verification.spec.ts for canonicalization and skew; integration tests to be added if using native Stripe signature parsing.
