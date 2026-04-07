-- 20250924_parking_forecast_package.sql
-- Forecast/fusion package with conflict-aware objects (idempotent)

-- Extensions
create extension if not exists postgis;
create extension if not exists pgcrypto;

-- 0. Common types
do $$
begin
  if not exists (select 1 from pg_type where typname = 'occupancy_confidence') then
    create type public.occupancy_confidence as (
      occupancy_pct numeric(5,2),
      sample_n int,
      variance numeric(8,4)
    );
  end if;
end$$;

-- 1. Source report tables (tenant RLS)
create table if not exists public.parking_reports (
  id uuid primary key default gen_random_uuid(),
  org_id uuid not null,
  source text not null default 'user' check (source in ('user','sensor','ingest')),
  observed_ts timestamptz not null,
  geom geometry(Point, 4326) not null,
  occupancy_pct numeric(5,2) not null check (occupancy_pct between 0 and 100),
  capacity int,
  payload jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);
create index if not exists idx_parking_reports_gix on public.parking_reports using gist (geom);
create index if not exists idx_parking_reports_ts on public.parking_reports (observed_ts desc);
alter table public.parking_reports enable row level security;

create table if not exists public.weighstation_reports (
  id uuid primary key default gen_random_uuid(),
  org_id uuid not null,
  observed_ts timestamptz not null,
  geom geometry(Point, 4326) not null,
  status text not null check (status in ('open','closed','delayed')),
  payload jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);
create index if not exists idx_weighstation_reports_gix on public.weighstation_reports using gist (geom);
create index if not exists idx_weighstation_reports_ts on public.weighstation_reports (observed_ts desc);
alter table public.weighstation_reports enable row level security;

-- Tenant policies
DO $$ BEGIN
  IF NOT EXISTS (select 1 from pg_policies where schemaname='public' and tablename='parking_reports' and policyname='parking_reports_tenant') THEN
    create policy parking_reports_tenant on public.parking_reports
      using (org_id::text = coalesce(current_setting('request.jwt.claims', true)::json->>'app_org_id',''))
      with check (org_id::text = coalesce(current_setting('request.jwt.claims', true)::json->>'app_org_id',''));
  END IF;
END $$;
DO $$ BEGIN
  IF NOT EXISTS (select 1 from pg_policies where schemaname='public' and tablename='weighstation_reports' and policyname='weighstation_reports_tenant') THEN
    create policy weighstation_reports_tenant on public.weighstation_reports
      using (org_id::text = coalesce(current_setting('request.jwt.claims', true)::json->>'app_org_id',''))
      with check (org_id::text = coalesce(current_setting('request.jwt.claims', true)::json->>'app_org_id',''));
  END IF;
END $$;

-- 2. Fused table
create table if not exists public.parking_fused (
  id uuid primary key default gen_random_uuid(),
  org_id uuid not null,
  site_id uuid null,
  geom geometry(Point,4326) not null,
  occupancy_pct numeric(5,2) not null,
  sample_n int not null default 0,
  variance numeric(8,4) null,
  last_observed_ts timestamptz not null,
  updated_at timestamptz not null default now()
);
create index if not exists idx_parking_fused_gix on public.parking_fused using gist (geom);
create index if not exists idx_parking_fused_org on public.parking_fused (org_id);
alter table public.parking_fused enable row level security;
DO $$ BEGIN
  IF NOT EXISTS (select 1 from pg_policies where schemaname='public' and tablename='parking_fused' and policyname='parking_fused_tenant') THEN
    create policy parking_fused_tenant on public.parking_fused for select using (
      org_id::text = coalesce(current_setting('request.jwt.claims', true)::json->>'app_org_id','')
    );
  END IF;
END $$;

-- 3. Forecast tables (conflict-aware for parking)
-- We try to create the time-series parking_forecast; if it already exists with a different schema, we create parking_forecast_ts instead.
DO $$ BEGIN
  IF NOT EXISTS (select 1 from information_schema.tables where table_schema='public' and table_name='parking_forecast') THEN
    create table public.parking_forecast (
      id uuid primary key default gen_random_uuid(),
      org_id uuid not null,
      site_id uuid null,
      geom geometry(Point,4326) not null,
      forecast_ts timestamptz not null,
      horizon interval not null,
      occupancy_pct numeric(5,2) not null,
      confidence numeric(5,2) null,
      sample_n int null,
      variance numeric(8,4) null,
      created_at timestamptz not null default now()
    );
    create index if not exists idx_parking_forecast_gix on public.parking_forecast using gist (geom);
    create index if not exists idx_parking_forecast_ts on public.parking_forecast (forecast_ts desc);
    create index if not exists idx_parking_forecast_org_ts on public.parking_forecast (org_id, forecast_ts desc);
    alter table public.parking_forecast enable row level security;
    IF NOT EXISTS (select 1 from pg_policies where schemaname='public' and tablename='parking_forecast' and policyname='parking_forecast_tenant') THEN
      create policy parking_forecast_tenant on public.parking_forecast for select using (
        org_id::text = coalesce(current_setting('request.jwt.claims', true)::json->>'app_org_id','')
      );
    END IF;
  ELSE
    -- If exists but without forecast_ts, create alternative table
    IF NOT EXISTS (
      select 1 from information_schema.columns where table_schema='public' and table_name='parking_forecast' and column_name='forecast_ts'
    ) THEN
      create table if not exists public.parking_forecast_ts (
        id uuid primary key default gen_random_uuid(),
        org_id uuid not null,
        site_id uuid null,
        geom geometry(Point,4326) not null,
        forecast_ts timestamptz not null,
        horizon interval not null,
        occupancy_pct numeric(5,2) not null,
        confidence numeric(5,2) null,
        sample_n int null,
        variance numeric(8,4) null,
        created_at timestamptz not null default now()
      );
      create index if not exists idx_parking_forecast_ts_gix on public.parking_forecast_ts using gist (geom);
      create index if not exists idx_parking_forecast_ts_ts on public.parking_forecast_ts (forecast_ts desc);
      create index if not exists idx_parking_forecast_ts_org_ts on public.parking_forecast_ts (org_id, forecast_ts desc);
      alter table public.parking_forecast_ts enable row level security;
      IF NOT EXISTS (select 1 from pg_policies where schemaname='public' and tablename='parking_forecast_ts' and policyname='parking_forecast_ts_tenant') THEN
        create policy parking_forecast_ts_tenant on public.parking_forecast_ts for select using (
          org_id::text = coalesce(current_setting('request.jwt.claims', true)::json->>'app_org_id','')
        );
      END IF;
    END IF;
  END IF;
END $$;

create table if not exists public.weighstation_forecast (
  id uuid primary key default gen_random_uuid(),
  org_id uuid not null,
  geom geometry(Point,4326) not null,
  forecast_ts timestamptz not null,
  horizon interval not null,
  status text not null check (status in ('open','closed','delayed','unknown')),
  confidence numeric(5,2) null,
  created_at timestamptz not null default now()
);
create index if not exists idx_weighstation_forecast_gix on public.weighstation_forecast using gist (geom);
create index if not exists idx_weighstation_forecast_ts on public.weighstation_forecast (forecast_ts desc);
create index if not exists idx_weighstation_forecast_org_ts on public.weighstation_forecast (org_id, forecast_ts desc);
alter table public.weighstation_forecast enable row level security;
DO $$ BEGIN
  IF NOT EXISTS (select 1 from pg_policies where schemaname='public' and tablename='weighstation_forecast' and policyname='weighstation_forecast_tenant') THEN
    create policy weighstation_forecast_tenant on public.weighstation_forecast for select using (
      org_id::text = coalesce(current_setting('request.jwt.claims', true)::json->>'app_org_id','')
    );
  END IF;
END $$;

-- 4. Refresh log
create table if not exists public.forecast_refresh_log (
  id bigserial primary key,
  kind text not null check (kind in ('parking','weighstation','fusion_parking')),
  started_at timestamptz not null default now(),
  finished_at timestamptz null,
  ok boolean null,
  rows_affected int null,
  message text null
);
create index if not exists idx_forecast_refresh_log_kind_time on public.forecast_refresh_log (kind, started_at desc);
alter table public.forecast_refresh_log enable row level security;
DO $$ BEGIN
  IF NOT EXISTS (select 1 from pg_policies where schemaname='public' and tablename='forecast_refresh_log' and policyname='forecast_refresh_log_read_admin') THEN
    create policy forecast_refresh_log_read_admin on public.forecast_refresh_log
      for select using ((coalesce(current_setting('request.jwt.claims', true)::json->'app_roles','[]'::json) ? 'admin'));
  END IF;
END $$;

-- 5. Fusion function
create or replace function public.fuse_parking_reports(half_life_minutes int default 60, radius_meters int default 500)
returns int
language plpgsql
security definer
as $$
declare
  v_start timestamptz := now();
  v_rows int := 0;
begin
  insert into public.forecast_refresh_log (kind, started_at) values ('fusion_parking', v_start);

  with candidates as (
    select r.org_id, st_snaptogrid(r.geom, 0.0001) as key_geom, max(r.observed_ts) as last_ts
    from public.parking_reports r
    where r.observed_ts > now() - interval '24 hours'
    group by r.org_id, st_snaptogrid(r.geom, 0.0001)
  ),
  fused as (
    select c.org_id,
           st_centroid(st_collect(r.geom)) as geom,
           sum(r.occupancy_pct * exp(-extract(epoch from (now() - r.observed_ts))/60.0 / half_life_minutes)) /
           nullif(sum(exp(-extract(epoch from (now() - r.observed_ts))/60.0 / half_life_minutes)),0) as occ,
           count(*) as sample_n,
           stddev_pop(r.occupancy_pct) as stddev,
           max(r.observed_ts) as last_ts
    from candidates c
    join public.parking_reports r on r.org_id = c.org_id and st_dwithin(r.geom, c.key_geom, radius_meters)
    where r.observed_ts > now() - interval '24 hours'
    group by c.org_id, c.key_geom
  )
  insert into public.parking_fused (org_id, site_id, geom, occupancy_pct, sample_n, variance, last_observed_ts, updated_at)
  select org_id, null, geom,
         round(occ::numeric, 2) as occupancy_pct,
         sample_n,
         case when stddev is null then null else round((stddev*stddev)::numeric,4) end as variance,
         last_ts,
         now()
  from fused
  on conflict do nothing;

  get diagnostics v_rows = row_count;

  update public.forecast_refresh_log
    set finished_at = now(), ok = true, rows_affected = v_rows
  where id = (select id from public.forecast_refresh_log where kind='fusion_parking' order by started_at desc limit 1);

  return v_rows;
exception when others then
  update public.forecast_refresh_log
    set finished_at = now(), ok = false, message = sqlerrm
  where id = (select id from public.forecast_refresh_log where kind='fusion_parking' order by started_at desc limit 1);
  raise;
end$$;

-- 6. Forecast refresh functions (dynamic target for parking)
create or replace function public.refresh_parking_forecast(horizon interval default interval '12 hours', half_life_minutes int default 90, step_minutes int default 15)
returns int
language plpgsql
security definer
as $$
declare
  v_start timestamptz := now();
  v_rows int := 0;
  v_target text := 'public.parking_forecast';
begin
  -- detect target table
  if not exists (
    select 1 from information_schema.columns where table_schema='public' and table_name='parking_forecast' and column_name='forecast_ts'
  ) then
    v_target := 'public.parking_forecast_ts';
  end if;

  insert into public.forecast_refresh_log (kind, started_at) values ('parking', v_start);

  -- base rows from fused
  perform 1;
  execute format($f$
    with base as (
      select org_id, site_id, geom, occupancy_pct, sample_n, variance, last_observed_ts from public.parking_fused
    ),
    series as (
      select b.org_id, b.site_id, b.geom, b.occupancy_pct, b.sample_n, b.variance,
             gs as forecast_ts, %L::interval as horizon
      from base b
      cross join generate_series(date_trunc('minute', now()), date_trunc('minute', now()) + %L::interval, make_interval(mins => %s)) gs
    ),
    modeled as (
      select org_id, site_id, geom, forecast_ts, horizon,
             round((50 + (occupancy_pct - 50) * exp(-extract(epoch from (forecast_ts - now()))/60.0 / %s))::numeric, 2) as occ_pred,
             case when sample_n is null or sample_n = 0 then null else round(least(100, greatest(0, 100 - coalesce(variance,10)))::numeric,2) end as confidence,
             sample_n, variance
      from series
    )
    insert into %s (org_id, site_id, geom, forecast_ts, horizon, occupancy_pct, confidence, sample_n, variance, created_at)
    select org_id, site_id, geom, forecast_ts, horizon, occ_pred, confidence, sample_n, variance, now() from modeled
    on conflict do nothing
  $f$, horizon, horizon, step_minutes, half_life_minutes, v_target);

  GET DIAGNOSTICS v_rows = ROW_COUNT;

  -- prune old
  execute format('delete from %s where forecast_ts < now() - interval ''1 hour''', v_target);

  update public.forecast_refresh_log
    set finished_at = now(), ok = true, rows_affected = v_rows
  where id = (select id from public.forecast_refresh_log where kind='parking' order by started_at desc limit 1);

  return v_rows;
exception when others then
  update public.forecast_refresh_log
    set finished_at = now(), ok = false, message = sqlerrm
  where id = (select id from public.forecast_refresh_log where kind='parking' order by started_at desc limit 1);
  raise;
end$$;

create or replace function public.refresh_weighstation_forecast(horizon interval default interval '12 hours', step_minutes int default 15)
returns int
language sql
security definer
as $$
with last_state as (
  select org_id, geom,
         (array_agg(status order by observed_ts desc))[1] as status,
         max(observed_ts) as last_ts
  from public.weighstation_reports
  where observed_ts > now() - interval '24 hours'
  group by org_id, geom
),
series as (
  select ls.*, gs as forecast_ts, horizon from last_state ls
  cross join (select %L::interval as horizon) h
  cross join generate_series(date_trunc('minute', now()), date_trunc('minute', now()) + %L::interval, make_interval(mins => %s)) gs
)
insert into public.weighstation_forecast (org_id, geom, forecast_ts, horizon, status, confidence, created_at)
select org_id, geom, forecast_ts, horizon,
       coalesce(status,'unknown') as status,
       70.0 as confidence, now()
from series
on conflict do nothing
returning 1
$$;

-- 7. BBOX RPCs (dynamic for parking)
create or replace function public.bbox_parking(minx double precision, miny double precision, maxx double precision, maxy double precision, srid int default 4326)
returns table (
  id uuid,
  org_id uuid,
  site_id uuid,
  geom geometry(Point,4326),
  forecast_ts timestamptz,
  horizon interval,
  occupancy_pct numeric(5,2),
  confidence numeric(5,2),
  sample_n int,
  variance numeric(8,4),
  created_at timestamptz
)
language plpgsql
stable
security definer
as $$
begin
  if exists (select 1 from information_schema.columns where table_schema='public' and table_name='parking_forecast' and column_name='forecast_ts') then
    return query
      select pf.* from public.parking_forecast pf
      where pf.geom && st_makeenvelope(minx, miny, maxx, maxy, srid)
        and pf.forecast_ts between now() and now() + interval '12 hours'
      order by pf.forecast_ts
      limit 500;
  elsif exists (select 1 from information_schema.columns where table_schema='public' and table_name='parking_forecast_ts') then
    return query
      select pft.* from public.parking_forecast_ts pft
      where pft.geom && st_makeenvelope(minx, miny, maxx, maxy, srid)
        and pft.forecast_ts between now() and now() + interval '12 hours'
      order by pft.forecast_ts
      limit 500;
  else
    return;
  end if;
end$$;

create or replace function public.bbox_weighstation(minx double precision, miny double precision, maxx double precision, maxy double precision, srid int default 4326)
returns setof public.weighstation_forecast
language sql
stable
security definer
as $$
  select *
  from public.weighstation_forecast
  where geom && st_makeenvelope(minx, miny, maxx, maxy, srid)
    and forecast_ts between now() and now() + interval '12 hours'
  order by forecast_ts
  limit 500
$$;

-- 8. Grants
grant execute on function public.fuse_parking_reports(int,int) to authenticated;
grant execute on function public.refresh_parking_forecast(interval,int,int) to authenticated;
grant execute on function public.refresh_weighstation_forecast(interval,int) to authenticated;
grant execute on function public.bbox_parking(double precision,double precision,double precision,double precision,int) to authenticated;
grant execute on function public.bbox_weighstation(double precision,double precision,double precision,double precision,int) to authenticated;

-- 9. Metrics view (conflict-aware for parking)
create or replace view public.v_forecast_freshness as
with has_pf as (
  select exists (
    select 1 from information_schema.columns where table_schema='public' and table_name='parking_forecast' and column_name='forecast_ts'
  ) as ok
), has_pf_ts as (
  select exists (
    select 1 from information_schema.columns where table_schema='public' and table_name='parking_forecast_ts' and column_name='forecast_ts'
  ) as ok
)
select 'parking' as kind,
  case
    when (select ok from has_pf) then now() - (select max(forecast_ts) from public.parking_forecast)
    when (select ok from has_pf_ts) then now() - (select max(forecast_ts) from public.parking_forecast_ts)
    else null::interval
  end as lag
union all
select 'weighstation', now() - max(forecast_ts)
from public.weighstation_forecast;

-- 10. Optional seed (safe if functions exist)
-- DO NOT run automatically to avoid heavy writes; keep as comments for operators
-- select public.fuse_parking_reports(60, 500);
-- select public.refresh_parking_forecast(interval '12 hours', 90, 15);
-- select public.refresh_weighstation_forecast(interval '12 hours', 15);
