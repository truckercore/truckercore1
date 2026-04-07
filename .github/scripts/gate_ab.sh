#!/usr/bin/env bash
set -euo pipefail
DB="${READONLY_DATABASE_URL:?READONLY_DATABASE_URL required}"

# 1) weights sum to ~1 (A/B/C supported)
SUMBAD=$(psql "$DB" -Atc "
  with sums as (
    select key,
      coalesce(sum((v)::numeric),0) as s
    from ab_experiments, jsonb_each_text(weights)
    group by 1
  )
  select count(*) from sums where abs(s - 1) > 0.0001;
")
[ "${SUMBAD}" -eq 0 ] || { echo "::error ::ab_experiments.weights must sum to 1"; exit 1; }

# 2) feature_key must exist in feature_catalog (if present)
MISSING=$(psql "$DB" -Atc "
  do $$ begin
    if to_regclass('public.feature_catalog') is null then
      raise notice 'feature_catalog missing, skipping check';
    end if;
  end $$;
  select count(*) from ab_experiments e
  left join feature_catalog f on f.key = e.feature_key
  where (select to_regclass('public.feature_catalog')) is not null and f.key is null;
")
[ "${MISSING}" -eq 0 ] || { echo "::error ::experiment.feature_key not found in feature_catalog"; exit 1; }

# 3) No active experiments ended in the past
EXPIRED_ACTIVE=$(psql "$DB" -Atc "
  select count(*) from ab_experiments
  where status='active' and end_at is not null and end_at <= now();
")
[ "${EXPIRED_ACTIVE}" -eq 0 ] || { echo "::error ::active experiment has end_at in the past"; exit 1; }

echo "AB experiment gates OK"
