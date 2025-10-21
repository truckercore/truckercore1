# POIs Module Runbook

Activation: deploy poi/parking & poi/weigh; CORS GET/OPTIONS only; cache headers.

Monitoring: p95 ≤ 800ms; cache hit% > 70%; 5xx < 0.5%.

Rollback: remove function routes; data intact.

Hygiene: validate GISt index; analyze poi_state.
