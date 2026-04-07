# Environment setup (Supabase Functions + Stripe)

This guide shows how to set local shell variables and Supabase Function secrets needed by the repository’s Edge Functions. Copy/paste the snippets that match your shell.

Variables used in examples:
- SUPA_URL: https://<PROJECT_REF>.supabase.co
- FUNC_URL: https://<PROJECT_REF>.functions.supabase.co
- SERVICE_ROLE_KEY: service role key (server-only; never ship to clients)
- USER_JWT: a real signed-in user JWT (for user-authenticated calls)
- STRIPE_SECRET_KEY: Stripe secret key (sk_live_* or sk_test_*)
- STRIPE_WEBHOOK_SECRET: webhook signing secret (from Stripe CLI or Dashboard)
- PRICE_PRO: Stripe price id for your Pro plan (e.g., price_123)
- WEB_URL: your web app base URL (used by checkout success/cancel and billing portal return)
- SUPABASE_URL, SUPABASE_ANON_KEY, SUPABASE_SERVICE_ROLE_KEY: standard Supabase envs

Note: Many functions already read these names from Deno.env at runtime.

---

## Bash/Zsh (macOS/Linux)

```bash
export SUPA_URL="https://<PROJECT_REF>.supabase.co"
export FUNC_URL="https://<PROJECT_REF>.functions.supabase.co"
export SERVICE_ROLE_KEY="<SERVICE_ROLE_KEY>"      # server-only
export USER_JWT="<END_USER_JWT>"                  # a real signed-in user
export STRIPE_SECRET_KEY="<SK_LIVE_or_TEST>"
export STRIPE_WEBHOOK_SECRET="<whsec_from_stripe_cli_or_dashboard>"
export PRICE_PRO="<price_xxx>"
export SUPABASE_URL="$SUPA_URL"
export SUPABASE_ANON_KEY="<ANON_KEY>"
export SUPABASE_SERVICE_ROLE_KEY="$SERVICE_ROLE_KEY"
export WEB_URL="https://app.example.com"
```

Quick test calls:
```bash
# Billing overview (user-auth)
curl -sS "$FUNC_URL/billing_overview" -H "Authorization: Bearer $USER_JWT" | jq

# Create billing portal (user-auth)
curl -sS -X POST "$FUNC_URL/create_billing_portal" -H "Authorization: Bearer $USER_JWT" | jq

# Digest flush (service)
curl -sS "$FUNC_URL/digest_flush" -H "Authorization: Bearer $SERVICE_ROLE_KEY" | jq
```

Stripe webhook local test (optional):
```bash
# Forward Stripe events to your deployed function
stripe listen --forward-to "$FUNC_URL/stripe_webhook"
# If you copy the printed webhook signing secret, set it:
export STRIPE_WEBHOOK_SECRET="<whsec_from_stripe_cli>"
```

Supabase CLI: set function secrets (recommended)
```bash
# Example: set common secrets for multiple functions
supabase functions secrets set \
  SUPABASE_URL="$SUPA_URL" \
  SUPABASE_ANON_KEY="$SUPABASE_ANON_KEY" \
  SUPABASE_SERVICE_ROLE_KEY="$SERVICE_ROLE_KEY" \
  WEB_URL="$WEB_URL" \
  STRIPE_SECRET_KEY="$STRIPE_SECRET_KEY" \
  STRIPE_WEBHOOK_SECRET="$STRIPE_WEBHOOK_SECRET"

# Deploy (pick functions you use)
supabase functions deploy billing_overview create_billing_portal stripe_webhook \
  ai_router ai_usage_get region_rules_get analytics_kpis_export \
  push_sender digest_flush offline_replay referrals_daily_sweep
```

---

## Windows PowerShell

```powershell
$env:SUPA_URL = "https://<PROJECT_REF>.supabase.co"
$env:FUNC_URL = "https://<PROJECT_REF>.functions.supabase.co"
$env:SERVICE_ROLE_KEY = "<SERVICE_ROLE_KEY>"      # server-only
$env:USER_JWT = "<END_USER_JWT>"                  # a real signed-in user
$env:STRIPE_SECRET_KEY = "<SK_LIVE_or_TEST>"
$env:STRIPE_WEBHOOK_SECRET = "<whsec_from_stripe_cli_or_dashboard>"
$env:PRICE_PRO = "<price_xxx>"
$env:SUPABASE_URL = $env:SUPA_URL
$env:SUPABASE_ANON_KEY = "<ANON_KEY>"
$env:SUPABASE_SERVICE_ROLE_KEY = $env:SERVICE_ROLE_KEY
$env:WEB_URL = "https://app.example.com"
```

Quick test calls (PowerShell):
```powershell
# Billing overview (user-auth)
curl "$($env:FUNC_URL)/billing_overview" -H "Authorization: Bearer $($env:USER_JWT)" | jq

# Create billing portal (user-auth)
curl -Method POST "$($env:FUNC_URL)/create_billing_portal" -H "Authorization: Bearer $($env:USER_JWT)" | jq

# Digest flush (service)
curl "$($env:FUNC_URL)/digest_flush" -H "Authorization: Bearer $($env:SERVICE_ROLE_KEY)" | jq
```

Supabase CLI (PowerShell):
```powershell
supabase functions secrets set `
  SUPABASE_URL="$($env:SUPA_URL)" `
  SUPABASE_ANON_KEY="$($env:SUPABASE_ANON_KEY)" `
  SUPABASE_SERVICE_ROLE_KEY="$($env:SERVICE_ROLE_KEY)" `
  WEB_URL="$($env:WEB_URL)" `
  STRIPE_SECRET_KEY="$($env:STRIPE_SECRET_KEY)" `
  STRIPE_WEBHOOK_SECRET="$($env:STRIPE_WEBHOOK_SECRET)"
```

---

## Where each variable is used
- STRIPE_SECRET_KEY: billing_overview, create_billing_portal, stripe_webhook
- STRIPE_WEBHOOK_SECRET: stripe_webhook (signature verification)
- WEB_URL: create_checkout_session (success/cancel), create_billing_portal (return), referral_generate (share URL)
- SUPABASE_URL/SUPABASE_ANON_KEY: user-authenticated functions
- SUPABASE_SERVICE_ROLE_KEY: server-only functions (ingestors, webhooks, cron-style EFs)
- PRICE_PRO: convenience for clients or scripts; create_checkout_session expects price_id in the request body

Security reminder: never expose SERVICE_ROLE_KEY or STRIPE_SECRET_KEY in client apps. Use them only in Edge Functions or server environments.
