#!/usr/bin/env bash
set -euo pipefail
: "${READONLY_DATABASE_URL:?READONLY_DATABASE_URL not set}"
DB="$READONLY_DATABASE_URL"

# 1) Presentations reference valid feature keys
if psql "$DB" -At -c "select fp.key from public.feature_presentations fp left join public.feature_catalog fc on fc.key=fp.key where fc.key is null" | grep -q .; then
  echo "::error ::presentations reference unknown feature keys"; exit 1
fi

# 2) price_id mapped in stripe_price_map when present
if psql "$DB" -At -c "select fp.price_id from public.feature_presentations fp left join public.stripe_price_map sp on sp.price_id=fp.price_id where fp.price_id is not null and sp.price_id is null" | grep -q .; then
  echo "::error ::unmapped price_id in presentations"; exit 1
fi

# 3) Fail if any active presentation for premium/ai lacks headline or badge
BAD_COPY=$(psql "$DB" -At -c "select count(*) from public.feature_presentations fp join public.feature_catalog fc on fc.key=fp.key where fp.active and fc.tier in ('premium','ai') and (coalesce(fp.headline,'')='' or coalesce(fp.badge,'')='')")
if [ "${BAD_COPY:-0}" -ne 0 ]; then
  echo "::error ::active premium/ai presentations missing headline or badge (${BAD_COPY})"; exit 1
fi

# 4) Policy footgun (warn only): AI features overridden to free
CNT=$(psql "$DB" -At -c "select count(*) from public.feature_overrides where tier_override='free' and key like '%.ai_%'")
if [ "${CNT:-0}" -gt 0 ]; then
  echo "::warning ::AI features overridden to free (${CNT})"
fi

# 5) Variant hygiene: more than 2 variants per key/env
VAR=$(psql "$DB" -At -c "select count(*) from public.v_feature_variant_gaps")
if [ "${VAR:-0}" -gt 0 ]; then
  echo "::warning ::Too many variants for some features (${VAR})"
fi

echo "Feature catalog gates OK"