# Smoke Tests (Local)

Run these before pushing a PR:

1. Format & Analyze
```bash
dart format .
flutter pub get
flutter analyze
```

2. Unit/Widget Tests (with coverage)
```bash
flutter test --coverage -r expanded
# Optional threshold check (40%)
dart run scripts/coverage_check.dart 0.40
```

3. Simple API smoke (optional)
If you have a running Edge Functions URL in your environment:
```bash
export FUNCTIONS_URL=https://YOUR_PROJECT.functions.supabase.co
export SUPABASE_ANON=YOUR_ANON
# Legacy fallback (deprecated):
# export SUPABASE_ANON_KEY=YOUR_ANON

# ai_finance (stub)
curl -i -X POST -H "Authorization: Bearer $SUPABASE_ANON" -H "Content-Type: application/json" \
  -d '{"user_id":"test"}' "$FUNCTIONS_URL/ai_finance"

# driver_stops (ranked list around a point)
curl -s "$FUNCTIONS_URL/driver_stops?lat=41.65&lng=-83.53&radius_km=50" | jq .

# driver_parking_report (crowd parking update)
curl -s -X POST -H "Authorization: Bearer $SUPABASE_ANON" -H "Content-Type: application/json" \
  -d '{"location_id":"10000000-0000-0000-0000-000000000001","status":"limited","available_spots":18}' \
  "$FUNCTIONS_URL/driver_parking_report" | jq .

# If only legacy is available, use $SUPABASE_ANON_KEY in the Authorization header instead.
```

4. Build a web release locally
```bash
# With defines file if present
flutter build web --release --dart-define-from-file=configs/release.env.json
# Otherwise
flutter build web --release
```



## Promotions smoke (optional)

# Requires FUNCTIONS_URL, OPERATOR_JWT, DRIVER_JWT
# Export anon for testing curl auth headers where needed
# export SUPABASE_ANON=YOUR_ANON

# 1) Create a promo (operator)
# Note: adjust dates
curl -s -X POST -H "Authorization: Bearer $OPERATOR_JWT" -H "Content-Type: application/json" \
  -d '{"title":"$5 off Diesel","type":"amount","value_cents":500,"start_at":"2025-09-19T00:00:00Z","end_at":"2025-12-31T23:59:59Z","channels":["QR","code"],"min_spend_cents":5000}' \
  "$FUNCTIONS_URL/promotions.create" | jq .

# 2) List nearby (driver)
# Response now includes score and factors for ranking/explainability
curl -s "$FUNCTIONS_URL/promotions.nearby?lat=41.65&lng=-83.53&radius_km=50" | jq .

# 3) Issue QR (driver)
ISSUE=$(curl -s -X POST -H "Authorization: Bearer $DRIVER_JWT" -H "Content-Type: application/json" \
  -d '{"promo_id":1,"device_hash":"abc123"}' "$FUNCTIONS_URL/promotions.issue_qr")
echo "$ISSUE" | jq .
TOKEN=$(echo "$ISSUE" | jq -r .token)

# 4) Redeem (scanner)
curl -s -X POST -H "Authorization: Bearer $OPERATOR_JWT" -H "Content-Type: application/json" \
  -d "{\"token\":\"$TOKEN\",\"cashier_id\":\"C-77\",\"subtotal_cents\":12000,\"location_id\":\"00000000-0000-0000-0000-000000000001\"}" \
  "$FUNCTIONS_URL/promotions.redeem" | jq .


## Operator Analytics — quick queries (optional)

These examples assume you have seeded data from docs/supabase/truck_stop_seed.sql and appropriate RLS policies.

- Latest per-location snapshot (fuel + parking):
```bash
curl -s "${SUPABASE_URL}/rest/v1/v_location_latest?select=location_id,name,parking_status,available_spots,diesel_effective_cents,score&limit=10" \
  -H "apikey: ${SUPABASE_ANON:-$SUPABASE_ANON_KEY}" -H "Authorization: Bearer ${SUPABASE_ANON:-$SUPABASE_ANON_KEY}" | jq .
```

- Redemptions count (example table name: promo_redemptions) — adjust if your schema differs:
```bash
curl -s "${SUPABASE_URL}/rest/v1/promo_redemptions?select=count:id" \
  -H "apikey: ${SUPABASE_ANON:-$SUPABASE_ANON_KEY}" -H "Authorization: Bearer ${SUPABASE_ANON:-$SUPABASE_ANON_KEY}" | jq .
```

- Fuel price competitiveness (requires a market medians table/feed to be meaningful). As a placeholder, compare each location to chain median:
```sql
with latest as (
  select distinct on (location_id) location_id, (diesel_cents - coalesce(discount_cents,0)) as eff
  from fuel_prices order by location_id, effective_at desc
), stats as (
  select percentile_cont(0.5) within group (order by eff) as med from latest
)
select l.location_id, l.name, (diesel_cents - coalesce(discount_cents,0)) as my_price,
       (select med from stats) as chain_median,
       ((select med from stats) - (diesel_cents - coalesce(discount_cents,0))) as advantage_cents
from locations l
join fuel_prices fp on fp.location_id = l.location_id
qualify row_number() over (partition by l.location_id order by fp.effective_at desc)=1;
```

See also:
- Pricing tiers: docs/pricing/pricing_tiers.md
- Analytics dashboard layout: docs/operator_portal_analytics_dashboard.md
