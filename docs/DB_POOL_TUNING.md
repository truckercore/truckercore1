# DB Pool Tuning

- Target utilization: 50–70%.
- Pool max size per app instance: `(db_max * 0.6 / instances)` — leave headroom for migrations/cron.
- Enable connection reuse; set statement timeout (2–5s) and idle timeout (30–60s).
- Use prepared statements where feasible; avoid N+1 queries.
- Monitor: active connections, wait events, queue depth; alert on sustained >80% active or spikes in wait events (see observability/alert_rules/db_rules.json or perf_rules.json).
- Prefer pagination + projection (select only columns needed); keep transactions short.
