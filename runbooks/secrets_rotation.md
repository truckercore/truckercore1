# Secrets Rotation Runbook

Objective: Ensure all sensitive credentials rotate within policy (<= 90 days) and roll back safely if needed.

Inventory:
- Supabase service role key (env: SUPABASE_SERVICE_ROLE_KEY)
- Stripe secrets (STRIPE_SECRET, STRIPE_WEBHOOK_SECRET)
- Request signing secret (REQUEST_SIGNING_SECRET)
- Admin task HMAC (ADMIN_TASK_HMAC_SECRET)

Procedure:
1. Create new secret value; store in vault (primary + backup).
2. Update Supabase env and CI secrets; deploy.
3. Validate via `secrets_rotation_check` function; ensure staleCount=0.
4. For signed requests, verify positive and negative E2E tests pass.
5. Decommission old secret after 24h overlap (where supported).

Rollback:
- Restore previous secret from vault; redeploy env; rerun checks.

KPIs:
- Overdue secrets = 0
- Signed-request coverage = 100% for protected endpoints
