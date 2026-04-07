# Runbook: Rate Limit Spike

Triggered by alert: RateLimitSpike (sustained 429s)

1. Identify offending orgs/keys
- Inspect `rate_limit_429_total` by `org` on dashboard.
- Check API logs for high-frequency clients and routes involved.

2. Validate client behavior
- Ensure clients implement backoff/jitter and respect Retry-After.
- Confirm route is appropriate for the traffic pattern; suggest batching.

3. Mitigations (short-term)
- Temporarily raise per-key/org limits for trusted clients.
- Coordinate with the client to slow down traffic.
- If abuse suspected, throttle or revoke the API key.

4. Follow-ups (long-term)
- Tune per-route limits and quotas.
- Add caching or bulk endpoints.
- Publish guidance on best practices for clients.

Links:
- Dashboard: API 429 Count by Org
- Alert: RateLimitSpike