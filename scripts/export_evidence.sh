#!/usr/bin/env bash
set -euo pipefail
REL=${1:-$(date +%Y%m%d-%H%M)}
mkdir -p "evidence/$REL"

# 1) Config & decisions hash
sha256sum config/decisions.yml > "evidence/$REL/decisions.sha256" || true

# 2) IAM/ops health
curl -fsS "${FUNC_URL:?}/ops/health" | jq '.' > "evidence/$REL/ops_health.json"

# 3) AI factor coverage KPI
psql "${SUPABASE_DB_URL:?}" -At -c \
  "copy (select * from v_ai_factor_coverage_7d) to stdout with csv header" \
  > "evidence/$REL/ai_factor_coverage_7d.csv"

# 4) Slow RPC sample
psql "${SUPABASE_DB_URL:?}" -At -c \
  "copy (select * from v_pg_stat_slow limit 50) to stdout with csv header" \
  > "evidence/$REL/slow_queries.csv" || true

# 5) Soak result (if present)
test -f reports/k6.json && cp reports/k6.json "evidence/$REL/"

tar -czf "evidence/$REL.tgz" -C evidence "$REL"
echo "✅ Evidence bundle: evidence/$REL.tgz"
