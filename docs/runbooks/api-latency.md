# Runbook: API Latency (ApiLatencyP95High)

When the ApiLatencyP95High alert fires (p95 > 300ms for 10m):

1. Identify impacted route
- Check dashboard panel for the specific `route` label in the alert.
- Correlate with recent deploys or traffic spikes.

2. Check error rates and saturation
- Review `http_requests_total` by status codes for the same route.
- Inspect API pod CPU/Memory and DB CPU/IO; look for throttling.

3. Drill into dependencies
- DB: slow queries for the endpoint; missing indexes; increased row sizes.
- External calls: timeouts/retries; elevated latencies from partners.

4. Mitigations (short-term)
- Roll back the last change touching this route if recent.
- Scale out API pods or DB read replicas.
- Add caching (response or sub-queries), reduce payload size, paginate.

5. Follow-ups (long-term)
- Add/query-level indexes, optimize N+1s.
- Add circuit breakers and timeouts for slow dependencies.

Links:
- Dashboard: TruckerCore — API Phase 4 Routes
- Alert: ApiLatencyP95High (non-prod)
