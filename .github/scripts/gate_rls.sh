#!/usr/bin/env bash
set -euo pipefail

if [[ -z "${READONLY_DATABASE_URL:-}" ]]; then
  echo "::error::READONLY_DATABASE_URL not set"
  exit 2
fi

TABLES=$(psql "$READONLY_DATABASE_URL" -Atc "
  select relname
  from pg_class c
  join pg_namespace n on n.oid=c.relnamespace
  where n.nspname='public' and relkind='r' and relname not like 'pg_%' and relname not like 'sql_%';
")

FAIL=0

for T in $TABLES; do
  CNT=$(psql "$READONLY_DATABASE_URL" -Atc \
    "select public.rls_simulate('${T}','true','{\"app_org_id\":\"ORG_B\",\"app_roles\":[\"driver\"]}');" || echo "0")
  if [[ "$CNT" =~ ^[0-9]+$ ]] && [ "$CNT" -gt 0 ]; then
    echo "::error file=$T::RLS leak detected ($CNT rows visible across tenant)"
    FAIL=1
  fi
done

exit $FAIL
