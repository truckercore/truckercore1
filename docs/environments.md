# Delivery governance and environments

This repository defines four deployment environments with a trunk‑based workflow and guardrails.

Environments
- sandbox: Ephemeral and/or shared environment for every merge to main. Auto‑deploy, fast feedback.
- staging: Stable pre‑prod for release verification and partner sandbox testing.
- canary: Small percentage of production traffic or a limited org cohort for early validation.
- prod: Full production.

Branch strategy
- Trunk‑based development. Short‑lived feature branches; squash merge to main behind feature flags.
- No long‑running release branches. Hotfix branches use the same CI gates and promotion path.

Promotion flow
1) Merge to main → CI gates → automatic deploy to sandbox. 
2) Manual promotion to staging (workflow_dispatch) after QA sign‑off. 
3) Manual promotion to canary (requires approval by Maintainers; allows partial rollout params). 
4) Manual promotion to prod (requires approval; can roll back via the same workflow).

CI gates (minimum)
- Static checks: formatting and analysis for Dart/Flutter + Node.
- Tests: unit tests; integration where applicable.
- Database safety: Supabase migration lint/dry‑run (if Supabase CLI configured).
- RLS tests: negative/positive access patterns executed against a test database (skips if secrets not configured).
- Security scans: npm audit (CI‑only), pub/dart advisories (best‑effort).
- Performance smoke: small API perf check (non‑blocking).

Feature flags
- All net‑new modules must be feature‑flagged and default off.
- A central registry exists at config/feature_flags.json and docs/feature_flags.md.

Acceptance
- Every merge to main auto‑deploys to sandbox via .github/workflows/deploy_sandbox.yml.
- Production promotions go through canary with manual approval via .github/workflows/deploy_promotion.yml.

Runbooks
- If an environment is red, block promotions forward until green.
- Rollback: re‑run the promotion workflow selecting the previous app/migration version or toggle flags off.
