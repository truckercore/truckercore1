# Rollout Runbook (Staging → Pilot → Broad)

Last updated: 2025-09-18

Owners
- Release DRI: <name>@<org>
- SRE On-call: <name>@<org>
- Mobile Lead: <name>@<org>
- Backend Lead: <name>@<org>

Evidence (attach links/screenshots as you go)
- Build numbers/SHAs: 
- Store console links (TF/Internal testing): 
- Dashboards: ingest/geofence/mini‑agg: 
- Dry run results (markdown upload): 
- Pilot cohort list: 

Checklist

1) Preconditions
- [ ] Release branch cut and tagged RC.
- [ ] CI green (unit/widget/e2e + store readiness).
- [ ] SRE on-call in session.

2) Staging Dry‑run (60–90 min)
- [ ] Toggle staging flags (see EFFECTIVE_FLAGS.md). Command: `npm run rollout:flags -- --env stage --enable geofence`
- [ ] Warm endpoints: `npm run rollout:warm -- --env stage`
- [ ] Smoke checks (app/web), then health SLOs: `npm run rollout:health -- --env stage`
  - Freshness ≤ 120s, Read p95 < 150ms (proxy), Ingest eval p95 < 10ms/pt, Stream vs batch drift ≤ 1% (if available)
- [ ] Exercise rollback/kill‑switch, verify bypass, then restore baseline.
- [ ] Capture evidence: `npm run rollout:evidence -- --env stage`

3) Pilot Enablement (24–48h)
- [ ] Enable flags for small cohort. See PILOT_ENABLEMENT.md.
- [ ] Verify kill‑switch end‑to‑end.
- [ ] Monitor dashboards/alerts clean 24–48h, telemetry delivery success > 99%.
- [ ] Define go/no‑go and rollback triggers (latency spikes, freshness > 300s, error rate > 1%, limit‑block surges).

4) Store Readiness Pass
- [ ] iOS: Internal TF live; reviewer notes + demo creds; permission copy/background modes visible; privacy labels match.
- [ ] Android: Internal track green; Pre‑launch report clean; Data Safety aligned; foreground service notification verified.
- [ ] `npm run rollout:store-ready` summary captured.

5) Broad Rollout Gates
- [ ] Ramp 10% → 50% → 100% only after pilot SLOs hold 48h and no critical issues. See BROAD_ROLLOUT_GATES.md.
- [ ] Daily audit: stream vs batch drift ≤ 1%, meters vs events align; alert summary posted.

6) Canary + Weekly Hygiene
- [ ] Start canary synthetic route feeding dashboards (freshness/latency sanity).
- [ ] Weekly report posted: freshness p95, read p95, accuracy vs batch, top org volumes, alert counts, incidents.

Notes
- Use scripts in scripts/release/* and config/rollout.json for env endpoints and dashboards.
- Always keep kill‑switch documented and tested.
