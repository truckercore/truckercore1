# Tiles Module Runbook

Activation: deploy cron cron.speed_tiles_v1; validate tile lag < 180s.

Monitoring: dashboards → tile build time p95, sec_lag, error rate.

Rollback: disable cron, keep table; no user-facing impact.

Hygiene: weekly VACUUM/ANALYZE on tiles_speed_agg.
