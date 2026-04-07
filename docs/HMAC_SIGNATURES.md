# HMAC Signatures for Partner Manifests

This document describes the HTTP signature header used by the partner manifest ingest/verify endpoints and our key rotation policy.

Header
- Name: `tc-hmac`
- Format: `tc-hmac alg=sha256, kid=<key-id>, ts=<unix-epoch-seconds>, sig=<hexsha256>`
- Signature payload: `${ts}.${rawBody}` (string concatenation)
- Algorithm: HMAC-SHA256
- Encoding: `sig` is hex-encoded lowercase; comparison is constant-time.

Validation Steps
1) Parse header and require fields: `alg`, `kid`, `ts`, `sig`.
2) Check `alg` is supported (currently `sha256`).
3) Enforce timestamp freshness: `|now - ts| <= 300s` (5 minutes).
4) Lookup `kid` in configured key set `HMAC_KEYS_JSON`.
5) Compute HMAC over `${ts}.${rawBody}` with the secret for `kid`.
6) Constant-time compare against `sig`.
7) If valid, proceed (ingest) or return ok (verify-only). Otherwise, return an error.

Key Rotation
- Maintain a small set of keys: `[{ kid, secret, alg, status: 'active'|'sunset'|'revoked' }]` in `HMAC_KEYS_JSON`.
- Accept signatures for `active` and `sunset` keys; reject `revoked`.
- Rotation procedure:
  1) Add new key with `status='active'`.
  2) Mark previous active key as `status='sunset'` for a grace period (7–30 days).
  3) Communicate `kid` and cutover date to partners.
  4) After grace, mark old key `status='revoked'` and remove from acceptance.
- Rotate quarterly and after any incident.

Partner Guidance
- Use UTC epoch seconds for `ts`.
- Keep at most two live keys (new `active` + old `sunset`).
- Retry on 5xx/429 with backoff and jitter.
- On `401 unknown_key` contact support with your `kid`.

Observability
- Consider logging `kid`, decision (`ok`/`bad_signature`/`stale_timestamp`/`unknown_key`), and timestamp skew for troubleshooting.
- Alert if verify/ingest signature failures spike or timestamp skew grows unexpectedly.
