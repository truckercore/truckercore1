#!/usr/bin/env bash
set -euo pipefail
DB="${READONLY_DATABASE_URL:?READONLY_DATABASE_URL required}"

echo "[verify] Partitions ensure/prune"
psql "$DB" -v ON_ERROR_STOP=1 -c "select public.usage_part_ensure(now());"
psql "$DB" -v ON_ERROR_STOP=1 -c "select public.usage_prune_old_parts(12);"

echo "[verify] Incremental rollup works (last 3 days)"
psql "$DB" -v ON_ERROR_STOP=1 -c "select public.usage_rollup_incremental(3);"

echo "[verify] Quota guard sample response"
psql "$DB" -v ON_ERROR_STOP=1 -c "select * from public.usage_may_consume(gen_random_uuid(),'ai.capacity.prediction',1);"

echo "[verify] Anomaly & drift views (should be empty initially)"
psql "$DB" -v ON_ERROR_STOP=1 -c "table public.v_usage_anomaly;" || true
psql "$DB" -v ON_ERROR_STOP=1 -c "table public.v_usage_sync_drift_sev;" || true

echo "[verify] Exec KPIs"
psql "$DB" -v ON_ERROR_STOP=1 -c "table public.v_usage_kpis;"

# Optional: freshness lag and cron health
echo "[verify] Freshness lag and cron health"
psql "$DB" -v ON_ERROR_STOP=1 -c "select * from public.v_usage_refresh_lag;" || true
psql "$DB" -v ON_ERROR_STOP=1 -c "table public.v_cron_health;" || true

echo "Usage verification completed."