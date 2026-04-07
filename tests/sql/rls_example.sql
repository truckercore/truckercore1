-- tests/sql/rls_example.sql
-- Purpose: verify RLS policy scopes reads by org_id via GUC app_org_id
-- Run with: psql -v ON_ERROR_STOP=1 -f tests/sql/rls_example.sql

-- Seed two rows for two orgs
insert into public.example_entities (org_id, name) values ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa','OrgA-One') on conflict do nothing;
insert into public.example_entities (org_id, name) values ('bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb','OrgB-One') on conflict do nothing;

-- Set GUC to OrgA and expect only OrgA rows
set local request.jwt.claims = '{"app_org_id":"aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa"}';
select count(*) as visible_org_a from public.example_entities;

-- Set GUC to OrgB and expect only OrgB rows
set local request.jwt.claims = '{"app_org_id":"bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb"}';
select count(*) as visible_org_b from public.example_entities;
