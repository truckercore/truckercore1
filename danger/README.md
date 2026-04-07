# Danger Rules

- PR title follows Conventional Commits. Bypass: `bypass:title`
- Runbook required if migrations change. Bypass: `bypass:runbook`
- Idempotency: new POST/PATCH/DELETE must call ensureIdempotent. Bypass: `bypass:idempotency`
- Probes artifacts required if probes changed. Bypass: `bypass:probes`
- OPA policy eval must produce reports/policy_eval.json. Bypass: `bypass:opa`
- New module under /module/<name> requires docs/runbooks/<name>. Bypass: `bypass:runbooks:module`
- New functions/** requires at least one *.test.ts|*.spec.ts. Bypass: `bypass:tests`
- Security hygiene: warn on SERVICE_ROLE_KEY in non-privileged code; fail on hard-coded secrets. Bypass: `bypass:sec`
