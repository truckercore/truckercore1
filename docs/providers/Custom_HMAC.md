# Custom HMAC (Default) Provider Profile

- Provider name: Custom HMAC
- Versioning: Use x-truckercore-event or payload field if applicable; allowed versions should be listed per integration.
- Required headers:
  - Signature: x-truckercore-signature (value format: sha256=<hex>)
  - Timestamp: x-truckercore-timestamp (unix seconds or ISO8601); millisecond epoch (>1e11) is rejected.
  - Optional: idempotency-key
- Timestamp formats: unix seconds (preferred) and ISO8601; future/past skew limited to ±60s by default.
- Signature scheme: HMAC-SHA256 over METHOD|path|ts|canonical_json_body (v2). Legacy v1 (ts.body) supported when method/path are not provided.
- Content types: application/json (default). Additional types must be explicitly allowlisted per integration.
- Replay: default 10 minutes. Payments/docs topics extended to 24h. Idempotency uses separate cache.
- IP allowlist: optional; document if enforced by integration layer.
- Tests: see tests/webhook_verification.spec.ts and tests/webhook.spec.ts for acceptance and rejection cases.
- Notes: Uses HKDF-scoped keys per org and endpoint; structured logs and metrics emitted for success/failure paths.
