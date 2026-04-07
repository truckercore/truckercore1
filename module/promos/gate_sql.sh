#!/usr/bin/env bash
set -euo pipefail
: "${SUPABASE_DB_URL:?}"
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; source "$DIR/../../scripts/gate_sql_common.sh"

require_nonzero "select count(*) from promotions where start_at<=now() and end_at>=now();"
explainq "select id from promotions where start_at<=now() and end_at>=now() order by start_at desc limit 10;"
echo "promos SQL gates ok"
