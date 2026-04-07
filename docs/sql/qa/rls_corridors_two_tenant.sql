-- docs/sql/qa/rls_corridors_two_tenant.sql
-- Manual QA for corridors RLS across two tenants

-- Preview two orgs (adjust as needed)
select id, name from organizations limit 2;

-- SESSION A (org A)
-- Simulate JWT claims
select set_config('request.jwt.claims', json_build_object('sub','user_a','org_id','00000000-0000-0000-0000-000000000000')::text, true);

-- Session A can read only its corridors
select * from corridors_view limit 5;

-- SESSION B (org B) — run in a separate session
-- select set_config('request.jwt.claims', json_build_object('sub','user_b','org_id','11111111-1111-1111-1111-111111111111')::text, true);
-- Expect zero rows from A's data
-- select count(*) from corridors_view where org_id = '00000000-0000-0000-0000-000000000000';

-- Attempt forbidden insert from B into A (should be blocked by RLS if insert enabled)
-- insert into corridors (org_id, geom, risk_score) values ('00000000-0000-0000-0000-000000000000', 'MULTILINESTRING((-100 40,-99 41))', 0.5);

-- Check index usage on org_id + updated_at via EXPLAIN
explain analyze
select id, org_id, updated_at from corridors
where org_id = '00000000-0000-0000-0000-000000000000'
  and updated_at > now() - interval '7 days'
order by updated_at desc
limit 50;