#!/usr/bin/env bash
set -euo pipefail
DB="${READONLY_DATABASE_URL:?READONLY_DATABASE_URL required}"

# Ensure SQL objects exist (optional if already applied in pipeline)
if [ "${APPLY_RLS_SQL:-1}" -eq 1 ]; then
  bash .github/scripts/rls_setup.sh
fi

# Run declarative RLS tests and fail if any failed in last hour
psql "$DB" -c "select public.rls_run_all_tests();"
psql "$DB" -c "table (select * from public.rls_test_results where ran_at>now()-interval '1 hour' and pass=false)" \
  | (! grep .) || { echo "::error ::RLS tests failing"; exit 1; }

# RLS lint gates
TU=$(psql "$DB" -Atc "select count(*) from public.v_rls_lint where is_true_using")
TC=$(psql "$DB" -Atc "select count(*) from public.v_rls_lint where is_true_check and cmd<>'all'")
GAPS=$(psql "$DB" -Atc "select count(*) from public.v_rls_insert_check_gaps")
if [ "$TU" -ne 0 ] || [ "$TC" -ne 0 ] || [ "$GAPS" -ne 0 ]; then
  echo "::error ::RLS lint: using=$TU check=$TC insert_gaps=$GAPS"
  exit 1
fi

# Claims drift chaos test for key tables
OK=$(psql "$DB" -Atc "select bool_and(public.rls_claims_drift_check(t)) from unnest(array['tenders','invoices']::regclass[]) t;")
[ "$OK" = "t" ] || { echo "::error ::Claims drift acceptance detected"; exit 1; }

# Performance guard for RLS queries
THRESH=${RLS_MEAN_MS_MAX:-250}
BREACH=$(psql "$DB" -Atc "select count(*) from public.v_rls_hot where mean_time > $THRESH;")
[ "$BREACH" -eq 0 ] || { echo "::error ::Slow RLS queries > ${THRESH}ms"; exit 1; }

echo "RLS gates passed."