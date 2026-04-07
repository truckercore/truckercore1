# Operator & Driver API (Supabase Edge Functions)

This document summarizes available Edge Function endpoints for the Operator Portal and the Driver app. All functions prefer SUPABASE_ANON in their environment, with a compatibility fallback to SUPABASE_ANON_KEY (deprecated).

Base path: https://<project-ref>.functions.supabase.co

Auth: Send the current user session JWT in Authorization: Bearer <token> for endpoints that require authentication.

## Driver

GET /driver_stops
- Purpose: Return ranked truck stops around a point with badges and explainability factors.
- Query params:
  - lat (number) – optional; if omitted returns top stops by score
  - lng (number) – optional
  - radius_km (number) – optional, default 50
- Response 200:
  {
    "stops": [
      {
        "location_id": "uuid",
        "name": "RR – I-80 Toledo",
        "lat": 41.65,
        "lng": -83.53,
        "score": 0.78,
        "confidence": 0.82,
        "badges": ["Most parking now", "Cheapest diesel"],
        "factors": { "parking": 0.82, "fuel": 0.65, "amenities": 0.6, "safety": 0.7, "detour": 0.9, "loyalty_boost": 0 }
      }
    ]
  }
- Notes: Uses stop_scores and stop_confidence tables. Personalization uses user_preferences when authenticated.

GET /promotions.nearby
- Purpose: Return active promos near a point, ranked by relevance score with explainability factors for "Why" chips.
- Query params:
  - lat (number) – required
  - lng (number) – required
  - radius_km (number) – optional, default 25
- Response 200:
  {
    "ok": true,
    "promos": [
      {
        "promo_id": 123,
        "title": "$0.10/gal off Diesel",
        "description": "Limited time discount",
        "type": "amount",
        "value_cents": 10,
        "channels": ["QR","code"],
        "location_id": "uuid",
        "org_id": "uuid",
        "distance_km": 4.2,
        "distance_mi": 2.6,
        "saved": false,
        "badges": ["Best Value","Cheapest fuel"],
        "score": 0.74,
        "factors": {
          "parking_score": 0.82,
          "fuel_discount_norm": 0.66,
          "brand_loyalty_weight": 1.0,
          "amenity_match": 0.2,
          "distance_inv": 0.75,
          "confidence": 0.8,
          "why_top": "fuel"
        }
      }
    ]
  }
- Notes:
  - Score blend example: 0.35*parking_score + 0.25*norm(fuel_discount_cents) + 0.15*brand_loyalty_weight + 0.15*amenity_match + 0.10*norm_inv(distance_mi) + 0.10*confidence.
  - norm_inv(distance) = 1/(1+alpha*mi) with alpha≈0.2. Fuel normalization uses min-max across results.
  - "saved" is true when the promo is in the caller's loyalty_wallet.
  - Location-scoped promos include a "This stop only" badge.

POST /driver_parking_report
- Purpose: Crowd-sourced parking update from drivers.
- Body JSON:
  {
    "location_id": "uuid",
    "status": "open|limited|full|unknown" (optional),
    "available_spots": 12 (optional),
    "capacity": 80 (optional)
  }
- Response 200: { "ok": true, "next_recompute_s": 120 }
- Notes: Writes a row into parking_status with source="crowd". Scoring recompute is trigger-based.

## Operator

GET /operator/locations_list
- Returns locations within the caller's scope (org/location_access) with recent parking and pricing fields.

POST /operator/parking_update
- Writes an operator parking update for a location in scope. Enforced by RLS.

## Scoring & Confidence (Database)

- fn_blend_parking_confidence(location_id uuid): blends parking confidence from sources with time-decay and weights (operator=1.0, crowd=0.7, iot=1.1) into stop_confidence.
- fn_compute_stop_score(location_id uuid): computes stop_scores(score, factors) using parking confidence, fuel price competitiveness and static placeholders for amenities/safety/detour.
- Triggers on parking_status/fuel_prices/promotions recompute the affected location.
- pg_cron refresh runs every 10 minutes to apply time decay.

## Environment Standards

- Prefer SUPABASE_ANON; legacy SUPABASE_ANON_KEY is supported with a deprecation warning.
- Web apps continue to use NEXT_PUBLIC_SUPABASE_ANON_KEY.

## Smoke Examples

- driver_stops:
  curl -s "${FUNCTIONS_URL}/driver_stops?lat=41.65&lng=-83.53&radius_km=50" | jq .

- driver_parking_report:
  curl -s -X POST \
    -H "Authorization: Bearer $SUPABASE_ANON" \
    -H "Content-Type: application/json" \
    -d '{"location_id":"10000000-0000-0000-0000-000000000001","available_spots":18,"status":"limited"}' \
    "$FUNCTIONS_URL/driver_parking_report" | jq .


---

## Related Docs
- Pricing tiers overview: docs/pricing/pricing_tiers.md
- Analytics dashboard layout: docs/operator_portal_analytics_dashboard.md
