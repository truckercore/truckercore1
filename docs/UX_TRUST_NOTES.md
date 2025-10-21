Title: Trust UX notes (chips + undo)

Chips (rendered on suggestions and plans)
- Why: show rationale summary (CPH gain, deadhead delta, trust %+)
- Compliance-checked: show when validation passed with region; include region code.
- Low data: show when region rules or telemetry coverage is missing/low.
- Broker trust: chips like "Median reply 28m", "Pays in 7 days", "Fraud watch" (severity color)

Undo (10s window)
- After user approves request/counter/plan apply, start a 10-second client timer.
- If user taps Undo, enqueue a compensating outbox job keyed by the same idem.
  - Example: { kind: "dispatch_plan_cancel", params: { idem, reason: "user_undo" } }
- Always append action_audit rows for both forward and undo actions.

Latency/SLO hints
- For propose/apply flows, aim p95 ≤ 800ms for propose and ≤ 1.5s for apply.
- Show degraded banner if status flags indicate read_only_mode or circuit_breakers=true.
