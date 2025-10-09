#!/usr/bin/env bash
set -euo pipefail
DB="${READONLY_DATABASE_URL}"

# 1) weights sum to 1
BAD=$(psql "$DB" -Atc "select count(*) from public.ab_experiments where (select coalesce(sum((value)::numeric),0) from jsonb_each_text(weights)) <> 1")
[ "$BAD" -eq 0 ] || { echo "::error ::ab_experiments weights must sum to 1"; exit 1; }

# 2) end_at not before start_at
BAD2=$(psql "$DB" -Atc "select count(*) from public.ab_experiments where end_at is not null and end_at <= start_at")
[ "$BAD2" -eq 0 ] || { echo "::error ::experiment end_at must be after start_at"; exit 1; }

# 3) feature keys exist
BAD3=$(psql "$DB" -Atc "select count(*) from public.ab_experiments e left join public.feature_catalog f on f.key=e.feature_key where f.key is null")
[ "$BAD3" -eq 0 ] || { echo "::error ::experiment.feature_key not found in feature_catalog"; exit 1; }

echo "AB admin gates OK"