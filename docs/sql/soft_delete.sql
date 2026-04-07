alter table if exists public.loads add column if not exists deleted_at timestamptz;

create or replace view public.loads_visible as
select * from public.loads where deleted_at is null;
