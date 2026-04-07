# Deploy All Supabase Schemas

This repository contains two kinds of database schema artifacts:
- Versioned migrations under `supabase/migrations` (applied with `supabase db push`).
- Standalone SQL files under `docs/supabase` (one‑time or environment hygiene scripts).

Use the provided scripts to deploy both sets in one go.

Prerequisites
- Supabase CLI installed and authenticated (`supabase login`).
- You have access to the target project (CLI will prompt or use flags as needed).

PowerShell (Windows)
```
# Apply migrations + all docs/supabase/*.sql (sorted)
powershell -File scripts/deploy_supabase_schemas.ps1

# Skip migrations and only apply docs SQL
powershell -File scripts/deploy_supabase_schemas.ps1 -SkipMigrations
```

Node (cross‑platform)
```
# Apply migrations + docs SQL
node scripts/deploy_supabase_schemas.mjs

# Skip migrations
node scripts/deploy_supabase_schemas.mjs --skip-migrations
```

What the scripts do
1) `supabase db push` — Applies all versioned migrations in `supabase/migrations`.
2) For each `*.sql` under `docs/supabase` (sorted by filename), runs `supabase db query -f <file.sql>`.
   - This is useful for one‑time owner/grant hygiene, observability tables/views, parking/ads hardening, etc.

Notes
- The scripts do not alter or re-order your migrations; they simply call the CLI.
- If any `docs/supabase/*.sql` file depends on objects from migrations, ensure the migration exists first (the default flow already runs migrations before docs SQL).
- For idempotency, the included SQL files are written defensively (IF NOT EXISTS / DO $$ checks) where possible.
- For production, run these in your CI/CD with the appropriate Supabase project selected (e.g., via `supabase link`).

Troubleshooting
- If a docs SQL file fails, fix the SQL and re-run the script; already-applied files remain applied.
- To see applied migrations, use `supabase db diff` or your usual migration management workflow.
