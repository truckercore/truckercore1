# Slack Provider Profile

- Provider name: Slack
- Versioning: Slack-Signature uses v0 hash format with timestamp v, but when proxied we normalize to v2 HMAC checks.
- Required headers:
  - Signature: X-Slack-Signature (format v0=<hex>); proxied to x-truckercore-signature sha256=<hex>
  - Timestamp: X-Slack-Request-Timestamp; proxied to x-truckercore-timestamp
- Timestamp formats: unix seconds (required)
- Signature scheme: Our verifier uses v2 METHOD|path|ts|body canonicalization once normalized at the edge.
- Content types: application/json (for Events API); handle url-encoded for legacy only if allowlisted explicitly.
- IP allowlist: Slack publishes IPs; document last review date.
- Tests: reuse core webhook tests; add provider-format parsing tests if native headers are consumed directly.
