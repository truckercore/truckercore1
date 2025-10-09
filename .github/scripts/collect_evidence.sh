#!/usr/bin/env bash
set -euo pipefail
OUT="${1:-artifacts/evidence}"
mkdir -p "$OUT"
TS=$(date -u +%FT%TZ)

if [ -z "${READONLY_DATABASE_URL:-}" ]; then
  echo "[warn] READONLY_DATABASE_URL not set; skipping evidence collection"
  exit 0
fi

psql "$READONLY_DATABASE_URL" -c "\\copy (select * from function_slo_last_24h) to STDOUT with csv header" > "$OUT/${TS}_function_slo.csv"
psql "$READONLY_DATABASE_URL" -c "\\copy (select * from rls_validation_results order by ran_at desc limit 100) to STDOUT with csv header" > "$OUT/${TS}_rls_results.csv"
psql "$READONLY_DATABASE_URL" -c "\\copy (select key, rotated_at, max_age_days from secrets_registry) to STDOUT with csv header" > "$OUT/${TS}_secrets_registry.csv"
psql "$READONLY_DATABASE_URL" -c "\\copy (select at, action, table_name, actor_org from audit_log where at > now() - interval '24 hours') to STDOUT with csv header" > "$OUT/${TS}_audit_log.csv"

sha256sum "$OUT"/*.csv > "$OUT/${TS}_checksums.txt"

# Optional: schema fingerprint
psql "$READONLY_DATABASE_URL" -c "\\copy (
  select md5(string_agg(ddl, '' order by ddl)) as schema_hash
  from (
    select pg_get_viewdef(oid) as ddl from pg_class where relkind='v'
    union all
    select pg_get_functiondef(oid) from pg_proc where pronamespace='public'::regnamespace
    union all
    select pg_get_tabledef(oid) from pg_class where relkind='r'
  ) as defs
) to STDOUT with csv header" > "$OUT/${TS}_schema_hash.csv"
