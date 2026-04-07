# Incident Runbooks (One-liners)

Realtime outage
- Action: Switch sockets to polling, increase backoff, and show "Realtime degraded" banner.
- Verification: Clients fall back to polling without errors; banner visible.

DB degraded
- Action: Set feature flag read_only_mode=true. Queue all writes to outbox; render lists/details from cache and show last updated timestamp.
- Verification: No direct writes attempted; outbox grows; banner visible.

Connector down
- Action: Trip circuit breaker (open). Serve cached results to clients; show "Integration degraded" banner.
- Verification: No live calls to connector; responses include degraded: true; banner visible.

Kill switch per feature
- Action: Flip feature flag off for the feature. Confirm banner (if applicable) and safe fallback behavior.
- Verification: Feature hidden/disabled; no errors in logs; UX explains limited functionality.
