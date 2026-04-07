# Webhook Storm Runbook

Symptoms: Elevated 429/5xx on webhook endpoints, backlog growing, provider retries spiking.

Immediate Actions:
- Enable provider backoff (if configurable) and reduce concurrency in workers.
- Activate idempotency guard dashboards to confirm duplicates are prevented.
- Temporarily queue incoming requests via CDN or edge proxy if needed.

Mitigations:
- Increase worker pool slowly; prioritize processing by provider event age.
- Add rate-limits per org using public.take_token() to protect shared resources.
- Coordinate with provider support; request retry window extension.

Verification:
- Backlog drains, error rate < 2%, p95 returns to baseline.
