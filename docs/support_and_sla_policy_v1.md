# Support & SLA Policy v1

Audience: Customers (Operators, Enterprise), Success, Support, Engineering
Last updated: 2025-09-19
Status: Ready to publish (v1)

---

## Support Tiers

- Free
  - Channels: Email support
  - Response target: ≤ 72h (business days)
  - Access: Public status page; community docs

- Business
  - Channels: Email + chat
  - Response target: 24–48h (business hours)
  - Coverage: Business hours; incident communications
  - Onboarding: Limited (self‑guided + templates)

- Enterprise
  - Channels: 24/7 support, priority queue
  - Response target: 24/7 with priority routing
  - Dedicated CSM; quarterly reviews
  - Custom onboarding and runbooks
  - SLA & Security: 99.9% availability target; security reviews on request

---

## SLA Targets (per calendar month)

Availability target: 99.9% monthly (≤ 43.8 minutes downtime)

Incident response targets:
- P0 (critical outage): acknowledge ≤ 15m, workaround ≤ 1h, resolve ≤ 4h
- P1 (major degradation): acknowledge ≤ 30m, resolve ≤ 8h
- P2 (minor issue): acknowledge ≤ 8h, resolve ≤ 5 business days

Disaster recovery (RTO/RPO)
- RTO: 4 hours (maximum tolerable downtime)
- RPO: 24 hours (point‑in‑time data recovery; daily backups; restore tests quarterly)

Measurement & Reporting
- Availability is measured across in‑scope components via uptime monitoring and server logs.
- Incident metrics recorded in status page history and post‑incident reports.

Service Credits
- Enterprise contracts may include service credits triggered when availability falls below the monthly target (per MSA/SOW).

---

## Scope of SLA

In‑scope components
- Operator Portal
- Driver App backend APIs
- Edge Functions (promotions, state, analytics)
- Auth/SSO (our control plane integration)
- Status page (public)

Exclusions
- Third‑party IdPs and carrier networks
- Mobile app store outages and distribution delays
- Customer on‑premise or ISP outages
- Force majeure events

---

## Incident Communications

Status page
- Public, with real‑time updates and historical incidents
- Components tracked: Portal, APIs, Edge Functions, Auth, Status page

Customer notices (templates)
- Initial notice (P0/P1): summary, impact, current status, next update ETA
- Resolution notice: root cause summary, recovery steps completed, any customer action
- RCA (within 5 business days): timeline, root cause, corrective actions, prevention

Update cadence
- P0: every 30 minutes or faster
- P1: hourly
- P2: as material updates occur

---

## On‑Call & Handoff Checklist (internal)

- Coverage schedule published and acknowledged
- Contact methods validated (pager, backup)
- Runbooks accessible (fusion/jobs, auth/SSO, promos)
- Access: prod dashboards, logs, DB read‑only, status page tool
- Handoff notes include: open incidents, follow‑ups, known risks

Escalation path
- L1 Support → On‑call Engineer → Incident Commander → Engineering Manager / Leadership

---

## Policies v1 Deliverables

- Support guide (channels, hours, escalation)
- Status page with historical incidents
- Incident comms templates
- On‑call rotation and handoff checklist

---

## Appendix: SLO Dashboards (reference)

See Observability docs for recommended dashboards and alerts:
- state endpoints p95 < 200 ms
- scanner‑to‑redeem < 800 ms
- uptime tracked with status page and synthetic checks

