# GitHub Provider Profile

- Provider name: GitHub
- Versioning: X-GitHub-Delivery, X-GitHub-Event, and optionally X-GitHub-Hook-Installation-Target.
- Required headers:
  - Signature: X-Hub-Signature-256 (format sha256=<hex>)
  - Timestamp: via request Date header or a proxy-injected x-truckercore-timestamp
  - Event: X-GitHub-Event
- Timestamp formats: prefer unix seconds via proxy; otherwise ISO8601 from Date.
- Signature scheme: HMAC-SHA256; our verifier uses v2 METHOD|path|ts|body canonicalization when integrated via our edge.
- Content types: application/json
- IP allowlist: GitHub publishes IP ranges; document last review date and matched CIDRs.
- Tests: unit tests in tests/webhook_verification.spec.ts cover skew, canonicalization; add integration tests when native header parsing is enabled.
