#!/usr/bin/env bash
set -euo pipefail
: "${SUPABASE_DB_URL:?}"

# tag from CI context or local fallback
tag="${GITHUB_REF_NAME:-local}"
ts="$(date -u +'%Y-%m-%d %H:%M UTC')"

# Pull optional k6 metrics if present
p95=$(jq -r '.metrics.http_req_duration["p(95.00)"]' reports/k6.json 2>/dev/null || echo "n/a")
p99=$(jq -r '.metrics.http_req_duration["p(99.00)"]' reports/k6.json 2>/dev/null || echo "n/a")
err=$(jq -r '.metrics.http_req_failed.rate' reports/k6.json 2>/dev/null || echo "n/a")

# Factor coverage KPI (via release KPIs view, idempotent)
factor_min=$(psql -At "$SUPABASE_DB_URL" -c "select coalesce(min_factor_cov_7d,100) from v_release_kpis limit 1" 2>/dev/null || echo "n/a")

cat > NOTES.md <<MD
# Release ${tag}

**When:** ${ts}

## Reliability
- Perf p95: \`${p95}\` ms
- Perf p99: \`${p99}\` ms
- Error rate: \`${err}\`

## Explainability
- AI factor coverage (min, 7d): \`${factor_min}%\`

## Evidence
- See attached \`evidence/*.tgz\` (config hash, health snapshot, slow queries, soak report)

## Sales
- ROI case study HTML + KPIs JSON attached in \`sales/\`
MD

echo "✅ NOTES.md written"
