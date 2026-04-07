# SLA and SLOs

## Service Level Agreement (SLA)
- Availability: 99.9% monthly (≤ 43.8 minutes downtime).
- Incident Response:
  - P0: acknowledge ≤ 15m, workaround ≤ 1h, resolve ≤ 4h
  - P1: acknowledge ≤ 30m, resolve ≤ 8h
- Exclusions: IdP outages, third‑party dependencies, force majeure.

## SLOs
- API latency: p95 ≤ 250 ms, p99 ≤ 800 ms.
- SSO success rate ≥ 98% daily.
- Promo redeem p95 ≤ 800 ms.

See also: docs/dashboards/platform_slo_dashboard.json and observability/alert_rules for alert wiring.

---

## Incident Response (Runbook — Summary)
- Detect & Triage: alerts → classify P0/P1/P2.
- Contain: feature flag off, rate‑limit, block IPs, rotate keys.
- Communicate: update public status page, use customer comms templates; maintain cadence until resolved.
- Recover: verify RTO/RPO; run regression checks; restore normal ops.
- RCA: publish within 5 business days; actions with owners and dates.

For full playbook, see security/IR_PLAYBOOK.md
