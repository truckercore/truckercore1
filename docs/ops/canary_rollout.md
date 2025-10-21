# Canary Rollout — Edge Functions Package

This document outlines a fast path to wire the Edge Functions canary package into CI, promote to a small cohort, and monitor/verify during the canary.

## 1) CI: Newman runner

We run the canary Postman collection in CI and publish an HTML report artifact.

- Local: `npm run ci:newman:edge-canary`
- CI: GitHub Actions workflow at `.github/workflows/edge-canary-newman.yml` runs on push/PR to main/master and uploads `newman/edge-canary.html`.

Expected inputs via env/secrets:
- POSTMAN_SIGNING_SECRET → used to inject `signing_secret` into the Postman environment at runtime.
- POSTMAN_API_KEY (optional) → not required unless your gateway expects it.

Collection path: `docs/postman/truckercore-canary-edge-functions.postman_collection.json`
Environment path: `docs/postman/truckercore-stage.postman_environment.json`

## 2) Promote to canary cohort (5–10%)

Flip feature flags for a small org cohort:
- integrations_mvp
- compliance_validator
- negotiation_assistant
- delay_prediction
- circuit_breakers (optional)

Keep per-flag kill switches ready. Document who is in the cohort.

## 3) Monitor during canary

Track per-function metrics:
- p95 latency and 5xx rate
- Idempotency duplicates (expect some due to retries; investigate spikes)
- Connector job outcomes (queued→running→ok), result.error messages

Suggested dashboards: function latency and error rate, connector_jobs status breakdown, duplicates per idem.

## 4) Verify security

- Ensure X-Signature (HMAC) required on public endpoints (already enforced in code)
- Confirm x-idem-key is required on write paths (connector jobs) and `duplicated:true` on repeats
- Validate RLS negative tests: cross-org claims see zero rows

## 5) Handy commands

- Local run (HTML report):
```
npm run ci:newman:edge-canary
```
- Direct newman (custom paths):
```
newman run docs/postman/truckercore-canary-edge-functions.postman_collection.json \
  -e docs/postman/truckercore-stage.postman_environment.json \
  --reporters cli,htmlextra \
  --reporter-htmlextra-export newman/edge-canary.html
```

## 6) Rollback plan

- If errors spike or SLOs regress, disable the feature flags above for the canary cohort.
- Re-run the Newman CI to verify recovery.
- File incident with links to dashboards and the latest `edge-canary.html` artifact.
