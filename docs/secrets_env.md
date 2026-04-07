# Supabase Edge Functions — Secrets per Environment

This repo is configured to keep secrets out of source control and to support separate environments (dev, staging, prod).

## Local secret files (never commit)
Create three local files at the project root (or where you run Supabase CLI):

- .env.dev
- .env.staging
- .env.prod

Each file contains environment variables for your Supabase Edge Functions, for example:

```
SUPABASE_URL=https://<project>.supabase.co
SUPABASE_ANON_KEY=eyJ...
SUPABASE_SERVICE_ROLE_KEY=eyJ...
STRIPE_SECRET_KEY=sk_test_...
STRIPE_WEBHOOK_SECRET=whsec_...
WEB_URL=https://app.example.com
BILLING_RETURN_URL=https://app.example.com/billing
BILLING_PORTAL_RETURN_URL=https://app.example.com/settings/billing
ENV_NAME=dev
```

Do not check these into git.

## Push secrets to Supabase per environment
If you manage multiple Supabase projects (recommended), run these in the correct project context or add `--project-ref`.

```
# Dev
supabase functions secrets set --env-file .env.dev

# Staging
supabase functions secrets set --env-file .env.staging

# Prod
supabase functions secrets set --env-file .env.prod
```

Useful ops:

- `supabase secrets list`
- `supabase functions serve --env-file .env.dev`
- `supabase secrets unset KEY_NAME` (for rotations)

## .gitignore best practices
The root .gitignore already ignores env files and allows checked-in examples:

```
.env*
!*.example
```

Keep a placeholder example (no secrets) if you need to document required keys (e.g., `supabase/.env.example`).

## Stripe/webhook multi-env hygiene
- Use separate Stripe accounts or keys per env.
- Create a webhook endpoint per env:
  - https://<dev-ref>.functions.supabase.co/stripe_webhook
  - https://<staging-ref>.functions.supabase.co/stripe_webhook
  - https://<prod-ref>.functions.supabase.co/stripe_webhook
- Store each endpoint’s `STRIPE_WEBHOOK_SECRET` in the matching `.env.*` and push with `functions secrets set`.

## Flutter — public config per environment
Only public values go into the app binary. This repo includes example dart-define JSON files:

- env/dev.json
- env/staging.json
- env/prod.json

Each contains at least:

```
{
  "SUPABASE_URL": "https://<project>.supabase.co",
  "SUPABASE_ANON_KEY": "<anon-key>",
  "ENV_NAME": "dev|staging|prod"
}
```

Build and run commands:

```
flutter run --dart-define-from-file=env/dev.json
flutter run --dart-define-from-file=env/staging.json
flutter build apk --dart-define-from-file=env/prod.json
```

The app reads values using `String.fromEnvironment` via `AppEnv`, and validates at startup (debug) with an assert.

Session storage: use `flutter_secure_storage` (or Supabase Flutter’s built-in secure session persistence) to persist/restore sessions. Never store service keys client-side.

## CI/CD tips
- Parameterize your pipeline to pick `.env.staging` vs `.env.prod` before deploy.
- Push secrets for that env, then deploy functions:

```
supabase functions secrets set --env-file .env.staging
supabase functions deploy
```

Sanity checks post-deploy:

- `curl` your function endpoint(s) to confirm expected 200/401 behavior
- `supabase secrets list` to confirm keys present
- Stripe CLI: `stripe listen --forward-to https://<ref>.functions.supabase.co/stripe_webhook`

## Security and SECRETS_DEF quick check
- Only use `SECURITY DEFINER` where needed; always include `set search_path = public` in such functions.
- Derive sensitive values (org_id, user_id) from JWT server-side; never trust client payload.
- RLS should block direct table writes where RPC/Edge enforcement is expected.
- Keep the service role out of client binaries, logs, and analytics.

## Optional extra — env health function
A lightweight function to verify deploy targets without exposing secrets.

Path: `supabase/functions/env_health/index.ts`

```
Deno.serve(() => {
  return new Response(JSON.stringify({
    env: Deno.env.get('ENV_NAME') ?? 'unknown',
    web_url: Deno.env.get('WEB_URL') ?? null
  }), { headers: { 'content-type': 'application/json' } });
});
```

Deploy and curl to ensure you’re hitting the expected environment.
