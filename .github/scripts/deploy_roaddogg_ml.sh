#!/usr/bin/env bash
set -euo pipefail

DB="${DATABASE_URL:-${READONLY_DATABASE_URL:-}}"
[ -n "${DB}" ] || { echo "::error ::DATABASE_URL or READONLY_DATABASE_URL required"; exit 1; }

# Apply order
# roaddogg_helpers.sql
# roaddogg_ml_core.sql
# roaddogg_spatiotemporal.sql
# roaddogg_ensembles.sql
# roaddogg_gate.sql
# roaddogg_read_views.sql
# roaddogg_governance.sql
# roaddogg_entitlements.sql (optional)
# roaddogg_seeds.sql (optional)

psql "$DB" -f docs/sql/roaddogg_helpers.sql
psql "$DB" -f docs/sql/roaddogg_ml_core.sql
psql "$DB" -f docs/sql/roaddogg_spatiotemporal.sql
psql "$DB" -f docs/sql/roaddogg_ensembles.sql
psql "$DB" -f docs/sql/roaddogg_gate.sql
psql "$DB" -f docs/sql/roaddogg_read_views.sql
psql "$DB" -f docs/sql/roaddogg_governance.sql
# Optional modules
psql "$DB" -f docs/sql/roaddogg_entitlements.sql || true
psql "$DB" -f docs/sql/roaddogg_seeds.sql || true

echo "Roaddogg ML SQL applied."