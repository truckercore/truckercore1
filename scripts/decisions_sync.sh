#!/usr/bin/env bash
set -euo pipefail
: "${SUPABASE_DB_URL:?}"
: "${ORG_ID:=}"  # empty -> global

cfg="$(cat config/decisions.yml)"
psql "$SUPABASE_DB_URL" -v ON_ERROR_STOP=1 <<SQL
with up as (
  insert into public.platform_decisions(org_id, config)
  values (NULLIF(:'ORG_ID','')::uuid, :'cfg'::yaml::jsonb)
  on conflict (org_id) do update
  set config = EXCLUDED.config, updated_at = now()
  returning 1
)
select 1;
SQL

echo "✅ decisions synced (${ORG_ID:-global})"
