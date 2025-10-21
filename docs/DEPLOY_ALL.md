# Deploy All Edge Functions

This repo includes multiple Supabase Edge Functions. Use the scripts below to deploy all of them in one command.

Functions covered
- ai_matchmaker
- org_job_worker
- org_queue_worker
- admin_diagnostics
- synthetic_load
- metrics_push
- stripe_webhooks

Prerequisites
- Supabase CLI installed and authenticated (supabase login)
- You have access to the target project (CLI will prompt or you can set envs)

PowerShell (Windows)
```
powershell -File scripts/deploy_all.ps1
# or skip verification/bundle checks
powershell -File scripts/deploy_all.ps1 -SkipBuild
```

Node (cross‑platform)
```
node scripts/deploy_all.mjs
# or
npm run functions:deploy:all
# Skip bundling verification
node scripts/deploy_all.mjs --skip-build
```

Notes
- The scripts simply run `supabase functions deploy <name>` sequentially.
- If you add/remove functions, update the lists in scripts/deploy_all.ps1 and scripts/deploy_all.mjs.
- Database migrations are not applied by these scripts. Apply migrations via your existing workflow (e.g., Supabase migrations or SQL editor) before invoking functions that depend on schema.
