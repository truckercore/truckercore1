# DR/BCP — Backups, Restore Drills, and Failover

This document captures our operational posture for disaster recovery and business continuity.

Status endpoint
- Edge Function: /functions/v1/status
- Contract:
  {
    "service": "truckercore",
    "state": "nominal|degraded|outage",
    "targets": { "rpo_min": 5, "rto_min": 30 },
    "indicators": {
      "last_full_backup_at": "<ISO>",
      "last_wal_archive_at": "<ISO>",
      "read_only_mode": false,
      "failover_mode": false
    }
  }
- FE banner rules:
  - state=degraded → show degraded banner with reason (read_only or failover)
  - state=outage → red outage banner

Backups
- Daily logical backups retained per policy.
- 7‑day WAL archive retained for point‑in‑time recovery.
- Purge job: follow infra policy to prune beyond retention.

Quarterly restore drill (target < 15 min)
1. Provision a staging DB and restore from latest full backup + WAL.
2. Create a temporary service role key and wire application to staging.
3. Verify: login succeeds, core read flows (loads list/details) work.
4. Record timings (start → able to login/read). Store RTO in ops log.

Read‑only mode simulation
- Flip feature flag read_only_mode=true (see docs/supabase/add_flags_readonly_failover.sql).
- Expected app behavior:
  - All Submit/Send actions queue into the outbox and surface a banner: "Pending—read‑only mode".
  - Lists/details render from cache and show “Last updated <timestamp>”.

Multi‑region failover drill (target < 30 min)
- Provision a warm replica (managed) in a secondary region.
- Configure DNS failover for Edge/Functions domain (short TTL).
- Flip failover_mode=true to orchestrate FE/BE degraded behavior:
  - Read calls go to replica; writes queue to outbox.
  - Banner: "Degraded—Failover".
- Measure time from trigger to serving traffic via replica.

Runbooks (see docs/ops/runbooks.md)
- Realtime outage → switch to polling + backoff; banner.
- DB degraded → set read_only_mode=true; queue writes; show last updated.
- Connector down → circuit breaker open; use cache; banner.
- Kill switch per feature → flip flag off; confirm banner and safe fallback.
