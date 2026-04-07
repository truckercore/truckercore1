#!/usr/bin/env bash
set -euo pipefail

DB="${DATABASE_URL:-${READONLY_DATABASE_URL:-}}"
[ -n "${DB}" ] || { echo "::error ::DATABASE_URL or READONLY_DATABASE_URL required"; exit 1; }

# Apply ML SQL in order:
# 1) ml_common_helpers.sql
# 2) ml_model_registry.sql
# 3) eta_feature_store.sql
# 4) eta_monitoring_views.sql
# 5) marketplace_ml.sql
# 6) fleet_driver_ml.sql
# 7) ops_demand_ml.sql
# 8) fin_nlp_ml.sql
# 9) supply_risk_ml.sql
# 10) calculate_eta_rpc.sql

psql "$DB" -f docs/sql/ml_common_helpers.sql
psql "$DB" -f docs/sql/ml_model_registry.sql
psql "$DB" -f docs/sql/eta_feature_store.sql
psql "$DB" -f docs/sql/eta_monitoring_views.sql
psql "$DB" -f docs/sql/marketplace_ml.sql
psql "$DB" -f docs/sql/fleet_driver_ml.sql
psql "$DB" -f docs/sql/ops_demand_ml.sql
psql "$DB" -f docs/sql/fin_nlp_ml.sql
psql "$DB" -f docs/sql/supply_risk_ml.sql
psql "$DB" -f docs/sql/calculate_eta_rpc.sql

echo "ML pack SQL applied."