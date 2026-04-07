# Freight Broker Dashboard — Suggested Delivery Plan

Timeline at a glance (6–8 weeks)

- M1 (Weeks 1–2): Free core (dashboard shell, KPIs, Quick Post, Loads list, Marketplace publish, basic chat, basic analytics cards)
- M2 (Weeks 3–4): Pro core (AI Match Suggestions, Offers/Negotiation, Compliance automation, E-Sign)
- M3 (Week 5): Exceptions Lane, Billing/Detention integration, Carrier Directory + Scorecards
- M4 (Weeks 6–7): APIs/Webhooks, full Analytics + Exports, A11y/Perf polish, Stripe gates & limits
- Week 8 (buffer): Stabilization, docs, sales demo data, GTM

Roles shorthand: PM, Design, FE (front-end), BE (backend/DB), QA (quality), Ops (infra/Stripe).

## Milestone M1 — Shipable Free Core (Weeks 1–2)

Objectives
- Broker Dashboard shell with logo watermark, KPI ribbon, Quick Post, Loads list, publish to Marketplace, basic per-load chat, basic analytics cards (read-only).

Key tasks
- Brand watermark: light/dark variants, 4–6% opacity, exclude modals/exports.
- KPI ribbon: Open Loads, Fill Rate, Avg Rate/mi (single lane), Time-to-Assign (read-only), Active Approved Carriers, Docs Pending.
- Quick Post Load: mini form + full “Post Load” page with templates.
- Loads list: filters (lane, equipment, status, window), bulk select, publish toggle.
- Marketplace publish: public listing on/off; boosted slot counter (Free: 3/mo).
- Basic Chat: per-load thread (Free cap: 3 active threads).
- Analytics mini-cards: fill rate trend, top lanes.

Owners & estimates
- Design: 2–3 d (dashboard + watermark + cards)
- FE: 6–8 d (shell, KPIs, Quick Post, Loads list, chat)
- BE: 4–6 d (KPI aggregates, publish flow, limits, basic chat persistence)
- QA: 2 d (flows, limits, empty states)

Dependencies
- Logo assets (light/dark SVG), lane/equipment enums, Marketplace endpoint.

DoD
- Creating/publishing a load updates Open Loads and appears in Marketplace; caps for active loads, boosted listings, and chat threads enforced for Free; watermark passes a11y.

## Milestone M2 — Broker Pro Core (Weeks 3–4)

Objectives
- AI Match Suggestions, Offers/Negotiation, Compliance automation, E-Sign flow. All premium-gated.

Key tasks
- AI Match Suggestions (Premium): shortlist with fit score + reasons (lane, proximity, equipment, HOS window).
- Outreach & sequencing (Premium): send offer (email/SMS/app), track open/reply; rate counters.
- Negotiation (Premium): structured counter/accept/withdraw; immutable audit.
- Compliance automation (Premium): COI/W-9/authority requests, expiry reminders; optional block assignment if missing.
- E-Sign (Premium): rate confirmation templates, multi-signer routing, final PDF + audit.

Owners & estimates
- Design: 3 d (suggestions list, offer modals, counters, e-sign states)
- FE: 8–10 d (suggestions, outreach UI, negotiation, compliance panel, e-sign)
- BE: 8–10 d (matching service, offer/sequence tracking, compliance requests, e-sign hooks, audits)
- QA: 3 d (end-to-end deals, gating)

Dependencies
- Carrier directory data, messaging provider (email/SMS), e-sign provider, Stripe broker_pro plan & claims.

DoD
- Sending an offer from Suggestions updates activity feed; counters/accept flip status to Assigned; missing docs can hard-block assignment when enabled; e-sign produces final, downloadable PDF with audit.

## Milestone M3 — Operations Enhancements (Week 5)

Objectives
- Exceptions Lane, Billing/Detention hooks, Carrier Directory + Scorecards.

Key tasks
- Exceptions Lane: expiring pickup windows, uncontacted loads >X min, missing docs, declined offers; actions: Ack, Assign, Snooze.
- Billing snapshot: draft/issued invoices, aging bands; detention/accessorial pre-fill hooks (Premium).
- Carrier Directory: approved/pending/blocked; quick filters and scorecards (acceptance %, on-time %, docs compliance).

Owners & estimates
- Design: 1–2 d
- FE: 5–6 d
- BE: 4–5 d
- QA: 2 d

Dependencies
- Detention timers from Loads/Stops, carrier KPIs.

DoD
- Exceptions stream shows new items within 60s; actions persist; detention lines flow into invoice drafts (Premium); scorecards display real carrier metrics.

## Milestone M4 — APIs, Analytics, Gating Polish (Weeks 6–7)

Objectives
- APIs/Webhooks, full Analytics + CSV/PDF exports, Stripe limits & gates, A11y/Perf polish.

Key tasks
- Analytics (full): time-to-assign by lane/customer (median/p90), rate/mi heatmap, carrier scorecards; CSV/PDF exports (Premium).
- APIs/Webhooks: load created/updated, offer events, assignment, docs; retries + signing.
- Stripe gates & limits: active loads/chat/boosts caps (Free); instant unlock (Pro).
- Polish: Lighthouse/Axe ≥95; list virtualization; socket resilience; empty/error states.

Owners & estimates
- Design: 1–2 d
- FE: 6–8 d
- BE: 6–8 d
- QA: 3 d (exports, rate-limits, webhooks)

Dependencies
- Stripe product/prices, signing secret for webhooks.

DoD
- Date range changes all charts; exports named with range; gates consistent; upgrade flips features live without reload; webhooks verified via test harness.

## Suggested Defaults & Thresholds

Exceptions Lane
- Uncontacted load: >15 min after posting
- Expiring pickup window: <90 min to window start
- Declined offers: ≥3 declines in 30 min
- Missing docs: any required item absent (COI, W-9, authority)
- SLA color: Green 95–100, Yellow 90–94.9, Red <90 (last 30d)

KPI Ribbon
- Default range: Last 7 days; trend vs previous 7
- Time-to-Assign target: <30 min (median) for hot lanes
- Docs Pending shows count + most critical type (e.g., “COI expiring in 5 days”)

Free caps
- 20 active loads, 3 active chat threads, 3 boosted listings/mo

Pro caps
- Effectively unlimited (enforce soft sanity limits only)

## Suggested Microcopy Library (paste into UI)

Upgrade banners (top of dashboard)
- “Unlock faster deals with AI matching, e-sign, and automated compliance checks.”
  - Button: Upgrade to Broker Pro — $149/mo

Disabled control tooltip (Free)
- “AI Match Suggestions is part of Broker Pro. Upgrade to auto-find best carriers for this lane.”

Offer sent
- “Offer sent to 12 carriers • 7 opened • 3 replied.”

Negotiation counter
- “Counter sent at $2.35/mi • Expires in 2 hours.”

Compliance block
- “Can’t assign: COI missing. Request documents or disable block in Settings.”

E-Sign complete
- “Rate confirmation signed • PDF saved to load documents.”

Exceptions item
- “Pickup window starts in 55 min — 0 contacts made.”
  - Actions: Ack • Send Offer • Snooze 15m

Marketplace boost (Free exhausted)
- “You’ve used 3 monthly boosts. Upgrade to Pro for unlimited boosts and priority placement.”

## Suggested Analytics & Alerts (Ops dashboards)

Track
- Post→first contact time, Post→assign time (median/p90)
- Offer open & reply rates by channel
- Fill rate by lane + customer
- Docs cycle time (request→complete)
- E-sign time (send→signed)
- Aging buckets $ and count

Alerts
- Open load with no contact in 30 min
- COI expiring in <7 days for active carriers
- Negotiation stuck >24 hours without activity
