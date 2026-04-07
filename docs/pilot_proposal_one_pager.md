# TruckerCore Pilot Proposal — 3-Month, 10–20 Locations (One‑Pager)

Audience: Truck stop operators (corporate and regional). Purpose: a concise, board‑ready proposal you can attach to email or PDF export.

Overview
- Objective: Validate measurable ROI from TruckerCore across fuel, parking, and in‑store uplift at a subset of locations.
- Duration: 3 months
- Scope: 10–20 locations (mix of high/medium volume; include at least 2 per region if applicable)
- Pricing: Based on Premium Operator band with pilot discount; see Pricing Calculator.

Goals (quantified)
- Fuel Gallons: +8–15% vs baseline at pilot locations
- Parking Conversion: +10–20% (drivers who park also purchase fuel/amenities)
- Promo Redemption: 500–1,500 approved redemptions total across pilot
- Review Score: +0.2–0.4 average star improvement (response SLAs in place)
- Decision: Clear go/no‑go threshold based on ≥2 KPI targets met and positive ROI

Key Workstreams & Deliverables
1) Setup (Week 0–2)
   - Data + Access: org + locations in system, staff invites/roles, POS webhook URL (if used)
   - Branding: logo, brand colors, hours/holidays, safety notices
   - Promotions: 2–3 fuel promos + 1–2 in‑store offers per pilot cohort
   - Parking: enable reporting; optional operator overrides and IoT if available
   - Success Plan: finalize KPIs, baselines, and reporting cadence

2) Go‑Live (Week 2–3)
   - Driver App: promos visible, ranked “Best for you” placement in target corridors
   - Scanner: QR + code redemption at participating stores
   - Operator Portal: Live Ops dashboard (parking, fuel price, scanner events)
   - Status & SLAs: status page link, incident comms templates agreed

3) Operate + Optimize (Week 3–10)
   - Weekly Review: KPI dashboard (fuel/parking/promos); adjust promos & hours
   - A/B Ideas: fuel discount levels, time‑windowed offers, parking messaging
   - Coaching: best practices for cashier flow and promo signage (poster QR)

4) Measure + Decide (Week 11–12)
   - Pilot Report: before/after KPIs, funnel conversion, ROI summary
   - Recommendation: scale plan, pricing band, timeline; or finalize exit report

Pilot KPIs (tracked weekly)
- Fuel
  - Gallons and revenue vs baseline and nearby median
  - Price competitiveness index (10–50 mi radius)
- Parking
  - Occupancy mix (open/some/full) and utilization heatmap
  - Conversion: parked → fuel or in‑store purchase proxy
- Promotions
  - Funnel: impressions → saves → scans → approvals → incremental revenue
  - Top promo drivers (by gallons and basket)
- Reputation
  - Avg review score, response time, trending topics

Success Criteria
- At least two of the following achieved across pilot locations:
  - +10% fuel gallons (baseline‑adjusted)
  - ≥15% improvement in parking conversion
  - ≥1,000 approved promo redemptions
  - +0.3 star review improvement with >70% response rate
- Operational fit confirmed (scanner latency < 800 ms p95, uptime ≥99.9%)

Commercials (pilot‑friendly)
- Pricing: Premium Operator monthly band (199–499 per stop) with multi‑location & prepay discounts; see calculator.
- Term: 3 months; option to convert to annual (locks pilot discount for first year).
- Setup: waived for pilot (standard 5k–25k optional services excluded).

Roles & Responsibilities
- Operator: designate pilot lead, approve promos/branding, ensure cashier readiness, post in‑store signage
- TruckerCore: implementation, training, dashboards, weekly ops review, incident comms

Risk & Mitigations
- Seasonal/market variance → use nearby median benchmarks and control locations
- Cashier friction → QR + code dual‑channel; poster QR and training kit
- Data sparsity early on → forecasting seed + conservative defaults; tuning available

Appendix
- RBAC & Roles (excerpt): corp_admin, regional_manager, location_manager access
- SLA Summary: 99.9% uptime target; P0/P1/P2 response targets (see Support & SLA policy)
- Security: short‑lived QR tokens, nonce, HMAC webhooks; audit logging

Next Steps
- Confirm pilot cohort and start date
- Complete branding + access checklist (1–2 days)
- Schedule 45‑min kickoff
- Point of contact: sales@truckercore.com
