#!/usr/bin/env bash
set -euo pipefail

DB="${DATABASE_URL:-${READONLY_DATABASE_URL:-}}"
[ -n "$DB" ] || { echo "::error ::DATABASE_URL or READONLY_DATABASE_URL required"; exit 1; }

psql "$DB" -f docs/sql/usage_events.sql
# Apply supporting usage modules
psql "$DB" -f docs/sql/usage_partitioning.sql
psql "$DB" -f docs/sql/usage_mv_refresh.sql
psql "$DB" -f docs/sql/usage_sync.sql
psql "$DB" -f docs/sql/usage_anomalies.sql
psql "$DB" -f docs/sql/usage_quotas.sql
psql "$DB" -f docs/sql/usage_pii_hygiene.sql
psql "$DB" -f docs/sql/usage_kpis.sql
psql "$DB" -f docs/sql/usage_ops_watch.sql
# Add top-up offers and ops.cron_health compatibility
psql "$DB" -f docs/sql/usage_topup.sql

echo "Usage events, rollups, maintenance & top-up SQL applied."