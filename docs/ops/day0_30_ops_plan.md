# Day‑0 → Day‑30 Ops Plan (copy‑paste friendly)

This page collects exact commands/SQL and drop‑in knobs for go‑live through the first 30 days.

## Day‑0 (cutover) — final sanity

Health and user chain (prod):

```
curl -s https://<REF>.supabase.co/functions/v1/health | jq .ok
curl -i https://<REF>.supabase.co/functions/v1/user-profile -H "Authorization: Bearer $JWT"
```

SLO snapshot:
```sql
select *
from public.edge_op_slo_24h
order by p95_ms desc
limit 50;
```

Nightly refresh last-run:
```sql
select job_name, last_run_at, rowcount
from public.nightly_refresh_status
order by last_run_at desc;
```

Rate limit check (expect 429 after threshold):
```
for i in {1..50}; do curl -s -o /dev/null -w "%{http_code}\n" https://<REF>.supabase.co/functions/v1/health; done
```

Logs flowing:
```sql
select *
from public.edge_request_log
order by ts desc
limit 20;
```

## Week‑1 (stabilization)

Alert tuning (≤ 2 alerts/day):
- Per-op thresholds: error_rate > 0.01 OR p95_ms > 800
- Global spike: errors_5m > 3 × mean_30m

Capacity sanity (off-peak):
- Reads p95 < 400ms @ 100–200 RPS (k6/gatling)
- Writes p95 < 600ms @ 20 RPS bursts (idempotent)

RLS audit:
```sql
-- logged in as a user from a different org
select *
from public.escalation_logs
limit 1;  -- expect zero rows
```

Index watch (hot query uses index):
```sql
explain analyze
select id, created_at
from public.some_hot_table
where org_id = :org
order by created_at desc
limit 25;
```

Secrets check (CI):
```
grep -R "SERVICE_ROLE" web_build/ dist/ | wc -l # expect 0
```

Retention prune (30 days):
```sql
delete from public.edge_request_log
where ts < now() - interval '30 days';
vacuum analyze public.edge_request_log;
```

## Week‑2 (resilience polish)

Blue/Green drill:
- Route user-profile to -v2 via header x-tc-func-ver: v2 (see functions/user-profile-router)
- Observe SLOs, promote default.

Rollback drill (10 min):
- Revert header or router default to -v1; confirm health/SLOs.

Incident playbook (one-page cheatsheet):
- 401/403 → verify JWT claims (app_org_id, roles).
- 429 → rate limit: check spikes and client retries.
- 5xx → check Edge logs, DB health, recent deploys.

## Week‑3 (observability maturity)

Dash tiles (pin in Studio):
```sql
-- Calls, Errors, Error-rate, p95 (last 24h)
select op,
       count(*) as calls,
       avg((status >= 500)::int) as error_rate,
       percentile_cont(0.95) within group (order by ms) as p95_ms
from public.edge_request_log
where ts >= now() - interval '24 hours'
group by op
order by p95_ms desc;

-- Top 10 offenders (last 1h)
select op, count(*) as errors
from public.edge_request_log
where ts >= now() - interval '1 hour'
  and status >= 500
group by op
order by errors desc
limit 10;

-- Materialized effectiveness freshness
select job_name, max(run_at) as last_refresh, max(row_delta) as last_delta
from public.refresh_effectiveness_runs
group by job_name
order by last_refresh desc;

-- Rate-limit hits per op (last 24h)
select op, count(*) as hits
from public.edge_request_log
where ts >= now() - interval '24 hours' and status = 429
group by op
order by hits desc;
```

Trace correlation (FE x-trace-id → Edge logs.trace_id):
```sql
select *
from public.edge_request_log
where trace_id = :trace
order by ts;
```

## Week‑4 (ops hygiene)

Key rotation (90-day): rotate SERVICE_ROLE_KEY; redeploy secrets; verify health.

Backups/DR: confirm PITR/backup retention; document restore steps and drill schedule.

Policy sweep (tenancy):
```sql
-- Tenancy fields/policies presence check (sample)
select table_name
from information_schema.columns
where table_schema='public' and column_name='org_id';

-- RLS enabled
select relname, relrowsecurity
from pg_class
where relname in ('table1','table2');  -- add tenant tables
```

Access pattern indexes: ensure (org_id, created_at desc) or relevant indexes exist per hot path

Last 5% hardening:
- Partition edge_request_log monthly (optional) to keep indexes tiny.
- Enforce idempotency on mobile write endpoints.
- Backpressure: return 503 if DB latency exceeds N ms to protect SLOs.

## Runbook snippets

Prod smoke (one-liner):
```
make smoke-remote PROJECT=<ref> USER_JWT=$JWT
```

SLO snapshot:
```sql
select op, calls, round(100*error_rate,2)||'%' as err, p95_ms
from public.edge_op_slo_24h
order by err desc nulls last, p95_ms desc;
```

Nightly job status:
```sql
select now() - max(ts) as since_last_log
from public.edge_request_log
where op like 'refresh-effectiveness%';
```

## Notes
- Nightly run tracking stored in public.nightly_refresh_status and public.refresh_effectiveness_runs.
- Health and user-profile functions already deployed in this repo.
- Rate-limit helper script: scripts/ops/rate_limit_check.sh or `make ops-rate-limit`.
