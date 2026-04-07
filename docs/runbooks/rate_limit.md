# Rate Limit Spike Playbook

Symptoms: Elevated 429 rate, user complaints of throttling.

1. Check metrics
- rate_limit_429_total by org and route
- API http_req_duration p95

2. Mitigations
- Identify offending keys/orgs; communicate quotas.
- Temporarily raise org caps if justified.
- Optimize hot endpoints and enable caching where possible.

3. Verification
- 429 rate returns to baseline; API p95 < 300ms.
