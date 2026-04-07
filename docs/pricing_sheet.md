# TruckerCore Pricing Sheet (Operator)

Audience: Sales, Operators (corporate/regional/location)
Last updated: 2025-09-19
Status: Ready to publish (v1)

---

## Plans and Bands (per location per month, USD)

Premium Operator (per-location subscription)
- Local band: $199 / month / stop
- Regional band: $349 / month / stop
- National feature set: $499 / month / stop

Enterprise Chain (custom)
- Chain contract with tiered discounts and enterprise features (SSO, SLAs, APIs, white‑label)

Notes
- Features scale with analytics depth, promotions, integrations, and support tier.

---

## Features by Band (summary)

- Local ($199)
  - Unlimited promotions (fuel, food, services)
  - QR & Code redemption for faster checkout
  - Featured placement in driver app (above non‑premium)
  - Parking dashboard (Open/Some/Full)
  - Basic analytics: promo funnel (view → save → redeem)

- Regional ($349)
  - Everything in Local
  - Fuel price competitiveness (10–50 mi radius)
  - ROI dashboards + CSV exports
  - Integrations: POS webhooks

- National ($499)
  - Everything in Regional
  - Executive analytics & forecasting (parking forecasts, benchmarking)
  - Advanced integrations: SSO, data feeds, enterprise roles
  - White‑label portal available

Enterprise (custom)
- National scale, SSO, SLAs, APIs, white‑label
- Corporate analytics: benchmarking, market share vs competitors
- Fleet integration: real‑time fuel/parking in dispatch; fleet‑only promos; digital receipts API

---

## Multi‑Location Discounts

Applied to the band price (Local/Regional/National) per active stop in the contract.

- 10–49 locations: 5% off
- 50–249 locations: 10% off
- 250+ locations: custom (target 12–18% based on term)

Examples
- 25 locations on Regional band ($349): 25 × 349 × 0.95 = $8,286.25 / month
- 120 locations on National band ($499): 120 × 499 × 0.90 = $53,892.00 / month

---

## Terms & Discounts

- Billing cadence (discounts off list):
  - Annual prepay: additional 8% discount
  - Quarterly prepay: 3% discount
  - Monthly: list price
- Setup fee (optional for on‑site training/integration): $5k–$25k based on scope
- Price protection: 12 months; renewal CPI cap 5%
- Add/remove locations prorated to month

Stacking behavior
- Volume discount applies first to band price
- Prepay discount applies to the discounted subtotal
- Setup fee billed separately

---

## Calculator (reference)

Given band_price, location_count, term, and prepay:

1) volume_discount =
   - 0.05 if 10 ≤ locations ≤ 49
   - 0.10 if 50 ≤ locations ≤ 249
   - custom if ≥ 250 (use quoted value)
   - else 0
2) prepay_discount = 0.08 (annual) | 0.03 (quarterly) | 0 (monthly)
3) subtotal = band_price × location_count × (1 − volume_discount)
4) monthly_due = subtotal × (1 − prepay_discount)
5) annual_due = monthly_due × 12 (if annual prepay)

---

## Sales Playbook Highlights

- ROI focus: promo uplift, parking conversions, fleet integrations
- Competitive: featured placement + analytics vs. “listing‑only” vendors
- Objection handling: start with pilot (10–20 locations), prove lift in 4–6 weeks

---

## Legal & Notes

- SLAs apply only to in‑scope TruckerCore components (see Support & SLA Policy v1).
- Exclusions: third‑party IdPs, carrier networks, app store outages.
- Taxes not included. All prices USD. Subject to MSA.
