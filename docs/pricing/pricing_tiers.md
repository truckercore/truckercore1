# Pricing Tiers (Truck Stop Operators)

This page outlines a ready-to-slot, three-tier plan you can reference in UI and billing. It aligns with our existing plan_catalog usage in Edge Functions.

## Free — Single Location Starter
- Users: 2 staff seats
- Locations: 1
- Promotions: Basic promos (manual create), static poster QR, manual codes
- Parking: Manual updates only
- Fuel: Manual price updates
- Scanner: QR/code redemption via web camera
- Analytics: Basic redemptions count, daily parking utilization, simple fuel sales summary
- Support: Community docs, email within 72h
- Data: 30-day retention for promo redemptions
- Ideal for: Independent stops testing promos and QR checkout

## Premium — Multi-Location Growth
Everything in Free, plus:
- Users: 20 staff seats; role-based access (HQ, regional, location)
- Locations: Up to 25 per org
- Promotions: Rules engine (caps, hours, SKU), chain & regional targeting, wallet saves, short-lived QR tokens
- Parking: IoT feed integration, confidence fusion (operator + crowd), alerts for stale data
- Fuel: Scheduled price changes, price competitiveness panel (10–50mi radius)
- Scanner: POS shortcode fallback, per-cashier analytics
- Analytics: Promo funnel (Impressions → Saves → Scans → Approved → Revenue), price competitiveness, parking heatmaps, driver segments, ROI exports (CSV)
- Webhooks: POS/ERP webhooks with HMAC signing
- Support: 24–48h business support, onboarding session
- Data: 180-day retention
- Ideal for: Regional brands and chains optimizing promos and revenue

## Enterprise — Chain-wide Executive
Everything in Premium, plus:
- Unlimited staff seats and locations
- SSO (SAML/OIDC), audit logs, custom roles
- Advanced Analytics (Executive pack): predictive forecasting (fuel/parking), fleet integration ROI, driver LTV, churn signals
- Integrations: Direct POS adaptors, loyalty/fleet card mapping, custom data feeds
- SLA: 99.9% uptime, priority support, solution architect
- Data: Multi-year retention and custom warehousing (Snowflake/BigQuery/S3)
- Ideal for: National brands with corporate analytics and custom integrations

---

## Feature Matrix Notes (implementation guidance)
- plan_catalog: Seed three Stripe price IDs (or placeholders) and a simple feature/limits JSON per plan. See docs/supabase/pricing_plan_seed.sql.
- Enforcement: 
  - Staff seat and location caps are enforced via Operator APIs (service role) and/or database constraints + RLS.
  - Premium-only features are already gated in functions as needed (e.g., webhooks, wallet saves, short-lived tokens).
- Billing Edge Functions already reference `plan_catalog` (create_checkout_session). Keep price IDs in sync.

## Copy suggestions for UI
- Free: “Get started with promos and QR checkout at a single location.”
- Premium: “Scale to regions with advanced analytics and automation.”
- Enterprise: “Security, integrations, and executive analytics at chain scale.”
