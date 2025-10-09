#!/usr/bin/env bash
set -euo pipefail

DB="${DATABASE_URL:-${READONLY_DATABASE_URL:-}}"
[ -n "${DB}" ] || { echo "::error ::DATABASE_URL or READONLY_DATABASE_URL required"; exit 1; }

# Deployment order:
# helpers.sql
# broker_core.sql → integrations.sql → share_links.sql
# carriers_matching.sql → carrier_verif_webhook.sql → capacity_market.sql
# live_map_view.sql → award_rules.sql → perf_indexes.sql

psql "$DB" -f docs/sql/helpers.sql
psql "$DB" -f docs/sql/broker_core.sql
psql "$DB" -f docs/sql/integrations.sql
psql "$DB" -f docs/sql/share_links.sql
psql "$DB" -f docs/sql/carriers_matching.sql
psql "$DB" -f docs/sql/carrier_verif_webhook.sql
psql "$DB" -f docs/sql/capacity_market.sql
psql "$DB" -f docs/sql/live_map_view.sql
psql "$DB" -f docs/sql/award_rules.sql
psql "$DB" -f docs/sql/perf_indexes.sql

echo "Broker core & integrations SQL applied."