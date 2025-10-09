#!/usr/bin/env bash
set -euo pipefail
DB="${READONLY_DATABASE_URL:?READONLY_DATABASE_URL required}"

# Apply RLS CI SQL in order
psql "$DB" -f docs/sql/rls_tests.sql
psql "$DB" -f docs/sql/rls_lint.sql
psql "$DB" -f docs/sql/rls_deny_default.sql
psql "$DB" -f docs/sql/claims_drift_test.sql
psql "$DB" -f docs/sql/rls_perf_watch.sql
psql "$DB" -f docs/sql/v_rls_kpis.sql

echo "RLS CI SQL installed."