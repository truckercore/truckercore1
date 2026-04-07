#!/usr/bin/env bash
set -euo pipefail
DB="${READONLY_DATABASE_URL:?READONLY_DATABASE_URL required}"

# Ensure the greenline SQL is installed (optional)
if [ "${APPLY_PACK_SQL:-1}" -eq 1 ]; then
  psql "$DB" -f docs/sql/pack_post_deploy_greenline.sql >/dev/null || true
fi

# 1) RLS greenline: ensure all pack tables have RLS ON and a SELECT policy
VIOL=$(psql "$DB" -Atc "select count(*) from public.v_pack_rls_greenline where not rls_on or not has_select_policy;")
if [ "${VIOL:-0}" -ne 0 ]; then
  echo "::error ::RLS greenline violations on pack tables (${VIOL})"
  psql "$DB" -c "table public.v_pack_rls_greenline" || true
  exit 1
fi

# 2) SecDef pinned: expect all listed functions pinned to search_path=public
UNPIN=$(psql "$DB" -Atc "select count(*) from public.v_pack_secdef_pinning where not pinned;")
if [ "${UNPIN:-0}" -ne 0 ]; then
  echo "::error ::SECURITY DEFINER functions not pinned to search_path=public (${UNPIN})"
  psql "$DB" -c "table public.v_pack_secdef_pinning" || true
  exit 1
fi

# 3) RLS lint: no TRUE USING/CHECK policies on pack tables
LINT=$(psql "$DB" -Atc "select count(*) from public.v_pack_rls_lint where is_true_using or is_true_check;")
if [ "${LINT:-0}" -ne 0 ]; then
  echo "::error ::Pack RLS lint violations (${LINT})"
  psql "$DB" -c "table public.v_pack_rls_lint" || true
  exit 1
fi

# 4) Cross-tenant leak probe using rls_simulate on sensitive pack tables
psql "$DB" -v ON_ERROR_STOP=1 <<'SQL'
drop table if exists tables_to_probe;
create temp table tables_to_probe (t text);
insert into tables_to_probe(t)
values ('export_jobs'), ('privacy_requests'), ('mobile_heartbeat'), ('access_attestations');
with tests as (
  select t,
         rls_simulate(t::regclass, 'true', '{"app_org_id":"ORG_B","app_role":"driver"}'::jsonb) as visible
  from tables_to_probe
)
select * from tests where visible > 0;
SQL

# If previous query returned any rows, fail (grep any content after header)
if psql "$DB" -Atc "with tests as (select t, rls_simulate(t::regclass, 'true', '{"app_org_id":"ORG_B","app_role":"driver"}') as visible from (values ('export_jobs'),('privacy_requests'),('mobile_heartbeat'),('access_attestations')) v(t)) select count(*) from tests where visible>0;" | grep -q '^[1-9]'; then
  echo "::error ::Cross-tenant RLS leak detected in pack tables"
  exit 1
fi

# 5) Optional retention call
psql "$DB" -c "select public.prune_old_partitions();" >/dev/null || true

echo "Pack greenline gates passed."