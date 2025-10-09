-- 908_spec_updates.sql
-- Align schema and RPCs with geography-backed nearby_loads, storage RLS, audit RPC, rollups, and payouts hardening

-- 0) Ensure extensions
create extension if not exists postgis;
create extension if not exists pgcrypto;

-- 1) Loads table GIS acceleration (pickup point + index)
alter table if exists public.loads
  add column if not exists pickup_geom geography(point, 4326)
  generated always as (
    case
      when pickup_lat is not null and pickup_lng is not null
      then geography(st_setsrid(st_makepoint(pickup_lng, pickup_lat), 4326))
      else null
    end
  ) stored;

-- delivered_at used by rollups (safe add)
alter table if exists public.loads
  add column if not exists delivered_at timestamptz;

create index if not exists idx_loads_pickup_geom on public.loads using gist (pickup_geom);

-- 2) Nearby loads RPC (geography + index-backed)
create or replace function public.nearby_loads(lat double precision, lng double precision, radius_miles double precision)
returns table (
  id uuid,
  origin_city text,
  dest_city text,
  pickup_lat double precision,
  pickup_lng double precision,
  miles numeric,
  rate_usd numeric
)
language sql stable set search_path=public as $$
  with origin as (
    select geography(st_setsrid(st_makepoint(lng, lat), 4326)) as g
  )
  select l.id, l.origin_city, l.dest_city, l.pickup_lat, l.pickup_lng, l.miles, l.rate_usd
  from public.loads l, origin o
  where l.pickup_geom is not null
    and st_dwithin(l.pickup_geom, o.g, radius_miles * 1609.34)
  order by st_distance(l.pickup_geom, o.g)
$$;

grant execute on function public.nearby_loads(double precision,double precision,double precision) to authenticated;

-- 3) Read-heavy IFTA trips index (org + ended_at desc)
create index if not exists idx_ifta_trips_org_ended_at_desc on public.ifta_trips (org_id, ended_at desc);

-- 4) Storage RLS for docs bucket (path-based)
-- Policies live on storage.objects
drop policy if exists doc_read_org on storage.objects;
create policy doc_read_org
on storage.objects for select to authenticated
using (
  bucket_id = 'docs' and
  exists (
    select 1
    from public.profiles p
    where p.user_id = auth.uid()
      and position(p.org_id::text || '/' in name) = 6
  )
);

drop policy if exists doc_write_org on storage.objects;
create policy doc_write_org
on storage.objects for insert to authenticated
with check (
  bucket_id = 'docs' and
  exists (
    select 1 from public.profiles p
    where p.user_id = auth.uid()
      and position(p.org_id::text || '/' in name) = 6
  )
);

-- 5) Function audit log (Edge RPCs)
-- Ensure table has required columns; add if missing
alter table if exists public.function_audit_log
  add column if not exists user_id uuid,
  add column if not exists ok boolean not null default false,
  add column if not exists meta jsonb not null default '{}'::jsonb,
  add column if not exists created_at timestamptz default now();

create index if not exists idx_function_audit_log_time on public.function_audit_log (created_at desc);

-- Helper RPC to insert audit rows securely
create or replace function public.audit(fn text, user_id uuid, meta jsonb, ok boolean default true)
returns void
language sql
security definer
set search_path = public
as $$
  insert into public.function_audit_log (fn, user_id, ok, meta)
  values (fn, user_id, coalesce(ok, true), coalesce(meta,'{}'::jsonb));
$$;

grant execute on function public.audit(text, uuid, jsonb, boolean) to authenticated;

-- 6) Daily rollups (idempotent upsert per (org_id,date))
create table if not exists public.org_metrics_daily (
  org_id uuid not null,
  date date not null,
  miles numeric(12,2) not null default 0,
  revenue_usd numeric(12,2) not null default 0,
  loads int not null default 0,
  created_at timestamptz default now(),
  primary key (org_id, date)
);

-- Adjust column types per spec where safe
do $$ begin
  if exists (
    select 1 from information_schema.columns
    where table_schema='public' and table_name='org_metrics_daily' and column_name='miles'
  ) then
    -- narrow to numeric(10,1) if wider
    begin
      alter table public.org_metrics_daily alter column miles type numeric(10,1);
    exception when others then
      -- ignore if incompatible; retain existing type
      null;
    end;
  end if;
end $$;

create or replace function public.rollup_org_metrics_daily(p_since date default (now()::date - 7), p_until date default now()::date)
returns int
language plpgsql
security definer
set search_path = public
as $$
declare
  v_rows int := 0;
begin
  with dates as (
    select generate_series(p_since, p_until, interval '1 day')::date as d
  ),
  orgs as (
    select distinct org_id from public.ifta_trips
    union
    select distinct org_id from public.loads
  ),
  cal as (
    select o.org_id, d.d as date
    from orgs o cross join dates d
  ),
  agg as (
    select
      c.org_id,
      c.date,
      coalesce((
        select sum(t.total_miles)::numeric(10,1)
        from public.ifta_trips t
        where t.org_id = c.org_id
          and t.ended_at >= c.date
          and t.ended_at < c.date + 1
      ),0) as miles,
      coalesce((
        select sum(l.rate_usd)::numeric(12,2)
        from public.loads l
        where l.org_id = c.org_id
          and l.delivered_at >= c.date
          and l.delivered_at < c.date + 1
      ),0) as revenue_usd,
      coalesce((
        select count(1)
        from public.loads l2
        where l2.org_id = c.org_id
          and l2.delivered_at >= c.date
          and l2.delivered_at < c.date + 1
      ),0) as loads
    from cal c
  )
  insert into public.org_metrics_daily (org_id, date, miles, revenue_usd, loads)
  select org_id, date, miles, revenue_usd, loads
  from agg
  on conflict (org_id, date) do update
  set miles = excluded.miles,
      revenue_usd = excluded.revenue_usd,
      loads = excluded.loads;
  get diagnostics v_rows = row_count;
  return v_rows;
end$$;

grant execute on function public.rollup_org_metrics_daily(date, date) to authenticated;

-- 7) Payout request hardening (computed net and load linkage)
-- Ensure table exists and mutate as needed
create table if not exists public.payout_requests (
  id uuid primary key default gen_random_uuid(),
  org_id uuid not null,
  user_id uuid not null,
  load_id uuid not null,
  amount_usd numeric(12,2) not null check (amount_usd >= 0),
  fee_usd numeric(12,2) not null default 0 check (fee_usd >= 0),
  net_amount_usd numeric(12,2) generated always as (greatest(amount_usd - fee_usd, 0)) stored,
  status text not null default 'pending' check (status in ('pending','approved','rejected','paid')),
  created_at timestamptz not null default now()
);

-- If payout_requests already existed with a different shape, patch it
do $$ begin
  if exists (
    select 1 from information_schema.columns
    where table_schema='public' and table_name='payout_requests' and column_name='load_id'
  ) then
    -- ok
  else
    alter table public.payout_requests add column load_id uuid;
  end if;
  -- relax amount_usd check: drop old if present and add new nonnegative check
  perform 1 from pg_constraint
   where conrelid = 'public.payout_requests'::regclass and conname = 'payout_requests_amount_usd_check';
  if found then
    alter table public.payout_requests drop constraint payout_requests_amount_usd_check;
  end if;
  begin
    alter table public.payout_requests add constraint payout_requests_amount_usd_nonneg_chk check (amount_usd >= 0);
  exception when duplicate_object then null; end;

  -- ensure fee_usd has default and not null
  begin
    alter table public.payout_requests alter column fee_usd set default 0;
  exception when undefined_column then null; end;
  update public.payout_requests set fee_usd = 0 where fee_usd is null;
  begin
    alter table public.payout_requests alter column fee_usd set not null;
  exception when others then null; end;

  -- re-create generated net_amount_usd with greatest(...,0)
  if exists (
    select 1 from information_schema.columns
    where table_schema='public' and table_name='payout_requests' and column_name='net_amount_usd'
  ) then
    alter table public.payout_requests drop column net_amount_usd;
  end if;
  alter table public.payout_requests add column net_amount_usd numeric(12,2) generated always as (greatest(amount_usd - coalesce(fee_usd,0), 0)) stored;
end $$;