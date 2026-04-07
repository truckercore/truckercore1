# Provider Profile Template

Use this template to document each webhook provider integration. Keep profiles concise and link to tests that validate the assumptions.

- Provider name: <provider>
- Contact / portal: <links>
- Versioning: <event version header/field and supported versions>
- Required headers:
  - Signature: <header name(s)>
  - Timestamp: <header name(s) and format(s)>
  - Event type/version: <header name>
- Timestamp format(s): unix seconds and/or ISO8601. State if milliseconds are ever used (should be rejected by our verifier).
- Signature scheme: sha256 HMAC; indicate whether method+path binding (v2) is required by the provider. Note legacy v1 if applicable.
- Content types: allowed content types (default is application/json).
- Replay window: expected window and idempotency semantics.
- Allowed IP ranges (if provider publishes them): link and note last review date.
- Test coverage:
  - Link to unit/integration tests in this repo that confirm header names, timestamp formats, signature expectations, and rejection paths.
- Special handling:
  - Any provider-specific quirks, schema drifts, or version deprecations.
- Change log:
  - Links to provider change announcements; date last reviewed.
