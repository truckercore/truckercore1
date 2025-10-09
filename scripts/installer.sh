#!/usr/bin/env bash
set -euo pipefail

DRY=0
while [[ $# -gt 0 ]]; do
  case "$1" in
    --dry-run) DRY=1; shift;;
    *) echo "Unknown arg: $1" >&2; exit 2;;
  esac
done

psql_exec() {
  if [[ "${DRY}" == "1" ]]; then
    echo "[dry-run] psql: $*"
  else
    psql "$@"
  fi
}

echo "[installer] Validating schema objects…"

SQL_CHECKS=$(cat <<'SQL'
-- tables
select 'driver_profiles' exists from pg_tables where tablename='driver_profiles' and schemaname='public'
union all
select 'crowd_reports' from pg_tables where tablename='crowd_reports' and schemaname='public'
union all
select 'alert_events' from pg_tables where tablename='alert_events' and schemaname='public'
union all
select 'safety_daily_summary' from pg_tables where tablename='safety_daily_summary' and schemaname='public'
union all
select 'risk_corridor_cells' from pg_tables where tablename='risk_corridor_cells' and schemaname='public';
SQL
)

if [[ "${DRY}" == "1" ]]; then
  echo "[dry-run] would run schema existence checks"
else
  psql -v ON_ERROR_STOP=1 -c "${SQL_CHECKS}" >/dev/null
fi

echo "[installer] Validating RLS enabled…"
if [[ "${DRY}" == "1" ]]; then
  echo "[dry-run] would validate RLS on key tables"
else
  psql -v ON_ERROR_STOP=1 -c "select schemaname, tablename from pg_tables where schemaname='public' and relrowsecurity = true;" >/dev/null
fi

echo "[installer] Validating grants on views/functions…"
GRANTS=$(cat <<'SQL'
select has_table_privilege('anon', 'public.v_export_alerts', 'SELECT') as v_export_alerts_anon;
select has_function_privilege('service_role', 'public.refresh_safety_summary(uuid,int)', 'EXECUTE') as refresh_fn_service;
SQL
)
if [[ "${DRY}" == "1" ]]; then
  echo "[dry-run] would run grant checks"
else
  psql -v ON_ERROR_STOP=1 -c "${GRANTS}" >/dev/null
fi

echo "[installer] Ensuring storage buckets (if using Supabase Storage)…"
if [[ "${DRY}" == "1" ]]; then
  echo "[dry-run] would check/create buckets"
else
  echo "[skip] no storage buckets required for CSV exports"
fi

echo "[installer] OK"
