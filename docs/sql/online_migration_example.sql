-- 1) create new column
alter table public.loads add column if not exists data_v2 jsonb;

-- 2) backfill in chunks (run in job)
-- update public.loads set data_v2 = json_build_object('legacy', data) where data_v2 is null limit 10000;

-- 3) swap reads via view
create or replace view public.loads_visible as
select id, org_id, data_v2 as data from public.loads where deleted_at is null;
