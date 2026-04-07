-- 20250924_forecast_overrides_rpc.sql
-- Forecast overrides + client RPCs + CV + verifier hardening (idempotent)

-- Prereqs
create extension if not exists postgis;
create extension if not exists pgcrypto;

-- 0) System audit (lightweight – do not alter if already exists with different shape)
create table if not exists public.system_audit_events (
  id bigserial primary key,
  org_id uuid null,
  actor_user_id uuid null,
  action text not null,
  entity_type text not null,
  entity_id uuid null,
  description text null,
  details jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);
create index if not exists idx_system_audit_events_org_time on public.system_audit_events (org_id, created_at desc);
alter table public.system_audit_events enable row level security;
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE polname='system_audit_read_admin') THEN
    CREATE POLICY system_audit_read_admin ON public.system_audit_events
    FOR SELECT USING ((coalesce(current_setting('request.jwt.claims', true)::json->'app_roles','[]'::json) ? 'admin'));
  END IF;
END$$;

-- 1) Time-series forecast tables if not present (names as per spec)
-- Note: if a conflicting parking_forecast already exists with a different schema,
-- RPCs below will read from a compatibility view instead (see section 3).
create table if not exists public.parking_forecast (
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
create index if not exists idx_parking_forecast_org_ts on public.parking_forecast (org_id, forecast_ts desc);
alter table public.parking_forecast enable row level security;
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE polname='parking_forecast_tenant') THEN
    CREATE POLICY parking_forecast_tenant ON public.parking_forecast
    FOR SELECT USING (org_id::text = coalesce(current_setting('request.jwt.claims', true)::json->>'app_org_id',''));
  END IF;
END$$;

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
create index if not exists idx_weighstation_forecast_org_ts on public.weighstation_forecast (org_id, forecast_ts desc);
alter table public.weighstation_forecast enable row level security;
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE polname='weighstation_forecast_tenant') THEN
    CREATE POLICY weighstation_forecast_tenant ON public.weighstation_forecast
    FOR SELECT USING (org_id::text = coalesce(current_setting('request.jwt.claims', true)::json->>'app_org_id',''));
  END IF;
END$$;

-- 2) Operator/partner overrides
create table if not exists public.parking_forecast_overrides (
  id uuid primary key default gen_random_uuid(),
  org_id uuid not null,
  site_id uuid null,
  geom geometry(Point,4326) not null,
  effective_from timestamptz not null,
  effective_to timestamptz not null,
  occupancy_pct numeric(5,2) null,
  status text null check (status in ('likely_full','likely_open')),
  confidence numeric(5,2) null,
  reason text null,
  source text not null default 'partner' check (source in ('partner','operator','admin')),
  created_by uuid null,
  created_at timestamptz not null default now()
);
create index if not exists idx_parking_overrides_org_time on public.parking_forecast_overrides (org_id, effective_from, effective_to);
create index if not exists idx_parking_overrides_gix on public.parking_forecast_overrides using gist (geom);
alter table public.parking_forecast_overrides enable row level security;
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE polname='parking_overrides_manage_org') THEN
    CREATE POLICY parking_overrides_manage_org ON public.parking_forecast_overrides
    FOR ALL TO authenticated
    USING (org_id::text = coalesce(current_setting('request.jwt.claims', true)::json->>'app_org_id',''))
    WITH CHECK (org_id::text = coalesce(current_setting('request.jwt.claims', true)::json->>'app_org_id',''));
  END IF;
END$$;

-- 2a) Audit trigger for overrides
create or replace function public.trg_log_parking_override_audit()
returns trigger
language plpgsql
security definer
set search_path = pg_catalog, public
as $$
begin
  insert into public.system_audit_events (org_id, actor_user_id, action, entity_type, entity_id, description, details)
  values (
    coalesce(new.org_id, old.org_id),
    nullif(coalesce(current_setting('request.jwt.claims', true)::json->>'sub',''), ''),
    tg_op,
    'parking_forecast_override',
    coalesce(new.id, old.id),
    case when tg_op='DELETE' then 'Override deleted' when tg_op='UPDATE' then 'Override updated' else 'Override created' end,
    to_jsonb(coalesce(new, old))
  );
  return coalesce(new, old);
end
$$;

drop trigger if exists parking_override_audit on public.parking_forecast_overrides;
create trigger parking_override_audit
after insert or update or delete on public.parking_forecast_overrides
for each row execute function public.trg_log_parking_override_audit();

-- 3) Compatibility view for time-series parking forecasts
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns WHERE table_schema='public' AND table_name='parking_forecast' AND column_name='forecast_ts'
  ) THEN
    -- If parking_forecast is NOT time-series, create a view with zero rows to keep RPCs safe.
    IF NOT EXISTS (SELECT 1 FROM information_schema.views WHERE table_schema='public' AND table_name='parking_forecast_ts_view') THEN
      EXECUTE $$create view public.parking_forecast_ts_view as
        select null::uuid as org_id,
               null::geometry(Point,4326) as geom,
               null::timestamptz as forecast_ts,
               null::numeric as occupancy_pct,
               null::numeric as confidence
        where false$$;
    END IF;
  ELSE
    -- Time-series table exists; bind the view to it.
    EXECUTE $$create or replace view public.parking_forecast_ts_view as
      select org_id, geom, forecast_ts, occupancy_pct, confidence from public.parking_forecast$$;
  END IF;
END$$;

-- 3a) get_forecast_poi RPC
create or replace function public.get_forecast_poi(
  p_geom geometry(Point,4326),
  p_window_start timestamptz default now(),
  p_window_end   timestamptz default now() + interval '6 hours'
)
returns table (
  kind text,
  forecast_ts timestamptz,
  status text,
  occupancy_pct numeric(5,2),
  confidence numeric(5,2),
  source text
)
language sql
stable
security definer
set search_path = pg_catalog, public
as $$
with ov as (
  select
    'parking'::text as kind,
    greatest(p_window_start, o.effective_from) as forecast_ts,
    o.status,
    o.occupancy_pct,
    o.confidence,
    'override'::text as source
  from public.parking_forecast_overrides o
  where st_dwithin(o.geom, p_geom, 100)
    and tstzrange(o.effective_from, o.effective_to, '[)') && tstzrange(p_window_start, p_window_end, '[)')
    and o.org_id::text = coalesce(current_setting('request.jwt.claims', true)::json->>'app_org_id','')
  order by o.effective_from desc
  limit 1
),
pf as (
  select
    'parking'::text as kind,
    f.forecast_ts,
    case when f.occupancy_pct >= 85 then 'likely_full'
         when f.occupancy_pct <= 50 then 'likely_open'
         else 'neutral' end as status,
    f.occupancy_pct,
    f.confidence,
    'model'::text as source
  from public.parking_forecast_ts_view f
  where st_dwithin(f.geom, p_geom, 200)
    and f.forecast_ts between p_window_start and p_window_end
  order by f.forecast_ts asc
  limit 1
),
ws as (
  select
    'weighstation'::text as kind,
    w.forecast_ts,
    w.status,
    null::numeric as occupancy_pct,
    w.confidence,
    'model'::text as source
  from public.weighstation_forecast w
  where st_dwithin(w.geom, p_geom, 500)
    and w.forecast_ts between p_window_start and p_window_end
    and w.org_id::text = coalesce(current_setting('request.jwt.claims', true)::json->>'app_org_id','')
  order by w.forecast_ts asc
  limit 1
)
select * from ov
union all
select * from pf
union all
select * from ws;
$$;

-- 3b) get_forecast_bbox RPC
create or replace function public.get_forecast_bbox(
  minx double precision, miny double precision, maxx double precision, maxy double precision, srid int default 4326,
  p_window_start timestamptz default now(),
  p_window_end   timestamptz default now() + interval '12 hours'
)
returns table (
  kind text,
  geom geometry(Point,4326),
  forecast_ts timestamptz,
  status text,
  occupancy_pct numeric(5,2),
  confidence numeric(5,2),
  source text
)
language sql
stable
security definer
set search_path = pg_catalog, public
as $$
with env as (
  select st_makeenvelope(minx,miny,maxx,maxy,srid) as box
),
pf as (
  select
    'parking'::text as kind,
    f.geom,
    f.forecast_ts,
    case when f.occupancy_pct >= 85 then 'likely_full'
         when f.occupancy_pct <= 50 then 'likely_open'
         else 'neutral' end as status,
    f.occupancy_pct,
    f.confidence,
    'model'::text as source,
    row_number() over (partition by st_snaptogrid(f.geom,0.0002), date_trunc('hour', f.forecast_ts) order by f.forecast_ts asc) as rn
  from public.parking_forecast_ts_view f, env e
  where f.geom && e.box
    and f.forecast_ts between p_window_start and p_window_end
),
pf_dedup as (
  select * from pf where rn = 1
),
ov as (
  select
    o.geom,
    greatest(p_window_start, o.effective_from) as effective_ts,
    o.status,
    o.occupancy_pct,
    o.confidence
  from public.parking_forecast_overrides o, env e
  where o.geom && e.box
    and tstzrange(o.effective_from, o.effective_to, '[)') && tstzrange(p_window_start, p_window_end, '[)')
    and o.org_id::text = coalesce(current_setting('request.jwt.claims', true)::json->>'app_org_id','')
),
pf_final as (
  select
    'parking'::text as kind,
    p.geom,
    coalesce(o.effective_ts, p.forecast_ts) as forecast_ts,
    coalesce(o.status, p.status) as status,
    coalesce(o.occupancy_pct, p.occupancy_pct) as occupancy_pct,
    coalesce(o.confidence, p.confidence) as confidence,
    case when o.geom is not null then 'override' else 'model' end as source
  from pf_dedup p
  left join lateral (
    select * from ov o2
    where st_dwithin(o2.geom, p.geom, 150)
    order by o2.effective_ts desc
    limit 1
  ) o on true
),
ws as (
  select
    'weighstation'::text as kind,
    w.geom,
    w.forecast_ts,
    w.status,
    null::numeric as occupancy_pct,
    w.confidence,
    'model'::text as source
  from public.weighstation_forecast w, env e
  where w.geom && e.box
    and w.forecast_ts between p_window_start and p_window_end
    and w.org_id::text = coalesce(current_setting('request.jwt.claims', true)::json->>'app_org_id','')
)
select kind, geom, forecast_ts, status, occupancy_pct, confidence, source from pf_final
union all
select kind, geom, forecast_ts, status, occupancy_pct, confidence, source from ws;
$$;

-- Grants for mobile RPCs
revoke all on function public.get_forecast_poi(geometry, timestamptz, timestamptz) from public;
revoke all on function public.get_forecast_bbox(double precision,double precision,double precision,double precision,int,timestamptz,timestamptz) from public;
grant execute on function public.get_forecast_poi(geometry, timestamptz, timestamptz) to authenticated;
grant execute on function public.get_forecast_bbox(double precision,double precision,double precision,double precision,int,timestamptz,timestamptz) to authenticated;

-- 4) Cross-validation results + function
create table if not exists public.forecast_cv_results (
  id bigserial primary key,
  org_id uuid not null,
  site_hash text not null,
  forecast_ts timestamptz not null,
  eval_window interval not null,
  forecast_pct numeric(5,2) null,
  actual_pct numeric(5,2) null,
  abs_error numeric(5,2) null,
  created_at timestamptz not null default now()
);
create index if not exists idx_forecast_cv_org_time on public.forecast_cv_results (org_id, forecast_ts desc);
alter table public.forecast_cv_results enable row level security;
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE polname='cv_read_org') THEN
    CREATE POLICY cv_read_org ON public.forecast_cv_results
    FOR SELECT USING (org_id::text = coalesce(current_setting('request.jwt.claims', true)::json->>'app_org_id',''));
  END IF;
END$$;

-- Minimal actuals source (only if missing)
create table if not exists public.parking_reports (
  id uuid primary key default gen_random_uuid(),
  org_id uuid not null,
  observed_ts timestamptz not null,
  geom geometry(Point,4326) not null,
  occupancy_pct numeric(5,2) not null check (occupancy_pct between 0 and 100),
  created_at timestamptz not null default now()
);
create index if not exists idx_parking_reports_gix on public.parking_reports using gist (geom);
create index if not exists idx_parking_reports_org_ts on public.parking_reports (org_id, observed_ts desc);
alter table public.parking_reports enable row level security;
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE polname='parking_reports_tenant') THEN
    CREATE POLICY parking_reports_tenant ON public.parking_reports
    FOR SELECT USING (org_id::text = coalesce(current_setting('request.jwt.claims', true)::json->>'app_org_id',''));
  END IF;
END$$;

create or replace function public.cross_validate_parking_forecast(eval_window interval default interval '30 minutes')
returns int
language sql
security definer
set search_path = pg_catalog, public
as $$
with f as (
  select st_snaptogrid(geom, 0.0002)::text as site_hash,
         forecast_ts,
         occupancy_pct as forecast_pct
  from public.parking_forecast_ts_view
  where forecast_ts between now() - interval '2 hours' and now() + interval '30 minutes'
),
a as (
  select st_snaptogrid(geom, 0.0002)::text as site_hash,
         date_trunc('minute', observed_ts) as observed_bucket,
         avg(occupancy_pct) as actual_pct
  from public.parking_reports
  where observed_ts between now() - interval '2 hours' and now() + interval '1 hour'
  group by st_snaptogrid(geom, 0.0002), date_trunc('minute', observed_ts)
),
joined as (
  select f.site_hash, f.forecast_ts, eval_window,
         f.forecast_pct,
         (select a2.actual_pct
          from a a2
          where a2.site_hash = f.site_hash
            and a2.observed_bucket between f.forecast_ts and f.forecast_ts + eval_window
          order by a2.observed_bucket asc
          limit 1) as actual_pct
  from f
)
insert into public.forecast_cv_results (org_id, site_hash, forecast_ts, eval_window, forecast_pct, actual_pct, abs_error)
select null::uuid as org_id, site_hash, forecast_ts, eval_window, forecast_pct, actual_pct,
       case when forecast_pct is not null and actual_pct is not null then abs(forecast_pct - actual_pct)::numeric(5,2) end
from joined
on conflict do nothing
returning 1
$$;

-- 5) Freshness view (guarded)
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema='public' AND table_name='parking_forecast' AND column_name='forecast_ts') THEN
    EXECUTE $$create or replace view public.v_forecast_freshness as
      select 'parking' as kind, now() - max(forecast_ts) as lag from public.parking_forecast
      union all
      select 'weighstation', now() - max(forecast_ts) from public.weighstation_forecast$$;
  ELSE
    EXECUTE $$create or replace view public.v_forecast_freshness as
      select 'weighstation' as kind, now() - max(forecast_ts) as lag from public.weighstation_forecast$$;
  END IF;
END$$;

-- 6) Verifier hardening
DO $$ BEGIN CREATE ROLE identity_audit NOINHERIT; EXCEPTION WHEN duplicate_object THEN NULL; END $$;

ALTER FUNCTION public.verify_identity_pack()
  SET search_path = pg_catalog, public;
REVOKE ALL ON FUNCTION public.verify_identity_pack() FROM public, authenticated;
GRANT EXECUTE ON FUNCTION public.verify_identity_pack() TO identity_audit;

create or replace view public.v_identity_pack_check as
select (j->>'ok')::boolean as ok, j->'missing' as missing, j->'notes' as notes
from (select public.verify_identity_pack() as j) t;

create or replace view public.v_rpc_grants_sanity as
select routine_schema, routine_name, grantee, privilege_type
from information_schema.role_routine_grants
where routine_name in ('check_export_allowed','verify_identity_pack')
order by 1,2,3;
