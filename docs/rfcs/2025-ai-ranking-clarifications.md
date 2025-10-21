# AI Ranking Clarifications

Owner: @you  | Due: YYYY-MM-DD  | Applies to: Driver map, Promos, Stops

## Required factors (at least 3)
- Top-5: ____, ____, ____, ____, ____

## Factor sourcing
- Parking: ☐ state.confidence ☐ operator weight ☐ crowd weight
- Fuel: ☐ discount_cents ☐ nearby median delta
- Distance: ☐ road distance ☐ straight-line distance
- Loyalty: ☐ brand match ☐ fleet preference
- Amenities: ☐ showers ☐ laundry ☐ repair ☐ food

## Sampling & storage
- Sample rate: ☐ 100% ☐ 10% ☐ 1% ☐ per-tenant override
- Persist factors: ☐ yes ☐ no  | Retention: __ days

## Explainability UX
- Show “Why” chips: ☐ on map ☐ on card ☐ on wallet
- Max chips per item: ☐ 3 ☐ 5
