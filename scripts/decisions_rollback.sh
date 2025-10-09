#!/usr/bin/env bash
set -euo pipefail
: "${SUPABASE_DB_URL:?}"
psql "$SUPABASE_DB_URL" -c "
with last as (
  select (metadata->'config')::jsonb cfg
  from audit_events
  where action='decisions_update'
  order by created_at desc limit 1
)
insert into platform_decisions(org_id, config)
select null, cfg from last
on conflict (org_id) do update set config=excluded.config, updated_at=now();
" >/dev/null
echo "✅ decisions rolled back to last audit snapshot"