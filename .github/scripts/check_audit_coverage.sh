#!/usr/bin/env bash
# .github/scripts/check_audit_coverage.sh
set -euo pipefail

: "${DATABASE_URL:?set DATABASE_URL}"

MISSING=$(psql "$DATABASE_URL" -Atc "
  with public_tables as (
    select n.nspname, c.relname
    from pg_class c join pg_namespace n on n.oid=c.relnamespace
    where n.nspname='public' and c.relkind='r'
  )
  select relname
  from public_tables
  except
  select table_name from audit_trigger_coverage where uses_logger and on_insert and on_update and on_delete;" || true)

if [ -n "$MISSING" ]; then
  echo "Missing audit triggers for tables:"
  echo "$MISSING"
  exit 1
fi

echo "Audit coverage OK"
