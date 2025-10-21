# Operator Portal — Analytics Dashboard (Layout Spec)

Navigation: Overview | Locations | Promotions | Scanner | Reviews | Analytics | Staff | Integrations | Settings

This document describes the target layout and widget content for the Analytics → Dashboard page. It is implementation-agnostic and can be used to scaffold UI components and data contracts.

## Header
- Filters: Date range, Org/Region/Location, Driver segment (fleet vs owner-op)

## KPI Strip (cards)
- Fuel Gallons (period) | Revenue | Promo Redemptions | Parking Utilization | Avg Dwell Time | Review Score

## Row 1: Fuel & Revenue
- Fuel Price Competitiveness (chart)
  - Line/area comparing your diesel/DEF vs local market median (10–50mi). Toggle by radius.
  - Insight badge: “5¢ cheaper vs median → +12% gallons (Fri–Sun)”
- Sales Uplift from Promos (tile + sparkline)
  - “$0.10 off promo → +18% gallons this weekend” with before/after comparison and confidence.

## Row 2: Promo ROI
- Promo Funnel (horizontal funnel)
  - Impressions → Saved → QR Scanned → Approved → Gallons Sold
  - Show conversion rates and drop-off highlights; badge top promo.
- Top Performing Promos (table)
  - Columns: Promo, Redemptions, Approval %, Revenue Uplift, Cost/Discount, ROI score.
  - Filter: brand-wide vs location-only.

## Row 3: Parking & Amenities
- Parking Utilization Heatmap (calendar/time heatmap)
  - Avg fill % by hour/day, peak badges; forecast callout: “80% by 8:15pm Fridays”.
- Amenities Usage (stacked bars)
  - Showers reservations, laundry cycles, repair bay queue time; trend arrows and correlation with fuel sales.

## Row 4: Driver Demographics & Behavior
- Who Stops Here? (donut + map)
  - Fleet vs owner-op %, top fleets, driver home-region heatmap.
- Dwell Time Analysis (box/violin plot)
  - Dwell by driver type; quick fuel vs overnight; correlation to promo redemption.

## Row 5: Marketing & Geo-Reach
- Customer Segmentation (cluster chart)
  - Redeemers by segment (fleet card, loyalty brand, owner-op).
- Geo-Reach Pathing (flow map)
  - Where drivers came from (directional bands: 50 mi north, 20 mi east), top lanes feeding location.

## Row 6: Safety, Reputation & Trust
- Reviews Dashboard (stacked trend + topics)
  - Avg rating; topic trends (cleanliness, safety, staff, Wi-Fi); trending complaints panel.
- Incident Reports & Nearby Alerts (list + map)
  - Recent incidents, inspection alerts nearby; compare your safety rating vs competitors.

## Row 7: Corporate & Multi-Location Insights
- Chain-wide KPIs (matrix)
  - Fuel sales, parking utilization, redemptions, review score by region; color-coded vs chain average.
- Benchmarking Leaderboard (table)
  - Over/under performers; quick actions to investigate (review trends, price competitiveness, staffing).
- Executive Analytics (Enterprise-only panel)
  - Predictive Forecasts (cards + confidence)
  - Fleet Integration ROI (tile)
  - Driver LTV & Churn (line + cohort)

---

## Data Sources and Notes
- Fuel competitiveness: requires local competitor feed or scraped market medians; can start with approximation if not integrated.
- Promo attribution: tie approved redemptions to gallons sold in redemption window (e.g., 2 hours).
- Forecasts: start with heuristics (last 8 weeks by weekday/hour), upgrade to ML later.
- Confidence badges: show band/CI when based on small sample sizes.

## Quick Wins & Alerts
- “Promo-driven gallons” and “Promo ROI” as immediate ROI panels.
- Alerts: “Stale parking feed (>30 min)”, “Price 10¢ above median for 3 days”, “Shower wait > 20 min spike.”
- Explainability: Each insight has a “Why” tooltip with underlying factors (e.g., parking confidence fusion of operator + crowd).

## Minimal Queries/Contracts (MVP examples)
These can be implemented as SQL views or RPCs and surfaced via Edge Functions or direct RLS reads.

- v_kpis(period, org_id?, region?, location_id?):
  - fuel_gallons, revenue_cents, promo_redemptions, parking_utilization_pct, avg_dwell_min, review_score
- v_promo_funnel(period,...):
  - impressions, saves, scans, approved, gallons_sold
- v_price_competitiveness(period, radius_miles,...):
  - my_price, median_price, p10, p90
- v_parking_heatmap(period,...):
  - hour_of_day, dow, utilization_pct
- v_top_promos(period,...):
  - promo_id, title, redemptions, approval_pct, revenue_uplift_cents, discount_cents, roi_score

