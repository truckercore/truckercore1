# Runbook — Example Module

## Activation
- Set FEATURE_EXAMPLE_ENABLED=true in staging (row in public.feature_flags), or flip via SQL:
  - update public.feature_flags set enabled=true, updated_at=now() where key='FEATURE_EXAMPLE_ENABLED';
- Smoke: run tests/sql/smoke_example.sql against the target DB.
- Enable in prod after soak by toggling the flag to true.

## Monitoring
- Metrics to track (add in your Edge/API as needed): example_api_latency_ms, example_api_errors_total
- Dashboards: “Example Module” latency, error rate < 1%
- Audit trail: ensure public.audit_log is populated for key changes if you emit rows.

## Rollback
- Disable FEATURE_EXAMPLE_ENABLED in feature_flags.
- Revert DB using the rollback helper (review and uncomment):
  - db/migrations/0014_example_entities_rollback.sql
- Restore snapshot if data corruption is suspected.

## Hygiene
- Weekly VACUUM (AUTO) and ANALYZE table public.example_entities.
- Index bloat check monthly; keep index idx_example_entities_org_status healthy.
- Purge soft-deleted rows via a maintenance job if you introduce soft-delete semantics later.

## Smoke test snippets (quick copy/paste)
```sql
-- Table exists
select to_regclass('public.example_entities');

-- Good insert
insert into public.example_entities (org_id, name) values ('11111111-1111-1111-1111-111111111111','Alpha') returning id;

-- Bad insert (expect failure)
do $$
begin
  begin
    insert into public.example_entities (org_id, name) values ('11111111-1111-1111-1111-111111111111','x');
    raise exception 'Constraint not enforced';
  exception when check_violation then
    null; -- OK
  end;
end$$;

-- Index check
explain analyze select * from public.example_entities where org_id='11111111-1111-1111-1111-111111111111' and status='active' limit 1;
```
