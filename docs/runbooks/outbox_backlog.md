# Outbox Backlog Playbook

Symptoms: Outbox pending depth/oldest age rising; webhook delivery p95 increases.

1. Check metrics
- truckercore_outbox_oldest_age_seconds
- truckercore_webhook_delivery_seconds p95
- truckercore_sub_in_flight by subscriber
- truckercore_sub_circuit_open_total

2. Mitigations
- Scale up workers.
- Enforce per-subscriber max_in_flight (lower for slow subscribers).
- Pause problematic subscribers; communicate with partner.
- Replay DLQ after fix using admin DLQ replay endpoint.

3. Verification
- Oldest age < 10m after recovery; delivery p95 < 15s steady-state.
