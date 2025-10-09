#!/usr/bin/env bash
set -euo pipefail

: "${DATABASE_URL:?DATABASE_URL required}"

SQL="
with stale as (
  select org_id, feature_key, min(first_seen_at) as first_seen_at
  from v_quota_softlimit_candidates
  group by org_id, feature_key
)
select s.org_id, s.feature_key, s.first_seen_at
from stale s
left join topup_offers o
  on o.org_id = s.org_id
 and coalesce(o.feature_key, o.feature) = s.feature_key
 and coalesce(o.status,'active') in ('active','issued')
where s.first_seen_at < now() - interval '7 days'
  and o.id is null;
"

OUT=$(psql "$DATABASE_URL" -At -c "$SQL" || true)
if [ -n "$OUT" ]; then
  echo "Upsell discipline violation: stale soft-limit candidates without top-up:"
  echo "$OUT"
  exit 1
fi

echo "Upsell discipline OK."