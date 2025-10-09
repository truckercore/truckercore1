-- POI + State + Fusion + BBox RPCs
-- Idempotent migration; safe to re-run

-- 0) Extensions
create extension if not exists cube;
create extension if not exists earthdistance;

-- 1) POIs core
create table if not exists public.pois (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  kind text not null check (kind in ('truck_stop','rest_area','weigh_station','wash','repair','fuel')),
  lat double precision not null,
  lng double precision not null,
  org_id uuid null,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);
create index if not exists idx_pois_kind on public.pois(kind);
create index if not exists idx_pois_earth on public.pois using gist (ll_to_earth(lat,lng));

alter table public.pois enable row level security;
drop policy if exists pois_read_all on public.pois;
create policy pois_read_all on public.pois for select to authenticated using (true);

-- 2) State tables
create table if not exists public.parking_state (
  poi_id uuid primary key references public.pois(id) on delete cascade,
  occupancy text not null check (occupancy in ('open','some','full','unknown')),
  confidence numeric(4,3) not null default 0.5,
  last_update timestamptz not null default now(),
  source_mix jsonb not null default '{}'::jsonb
);
create table if not exists public.weigh_station_state (
  poi_id uuid primary key references public.pois(id) on delete cascade,
  status text not null check (status in ('open','closed','bypass','unknown')),
  confidence numeric(4,3) not null default 0.5,
  last_update timestamptz not null default now(),
  source_mix jsonb not null default '{}'::jsonb
);

alter table public.parking_state enable row level security;
alter table public.weigh_station_state enable row level security;

-- read-all policies for clients
DO $$ BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies WHERE schemaname='public' AND tablename='parking_state' AND policyname='parking_state_read_all') THEN
    CREATE POLICY parking_state_read_all ON public.parking_state FOR SELECT TO authenticated USING (true);
  END IF;
END $$;
DO $$ BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies WHERE schemaname='public' AND tablename='weigh_station_state' AND policyname='weigh_state_read_all') THEN
    CREATE POLICY weigh_state_read_all ON public.weigh_station_state FOR SELECT TO authenticated USING (true);
  END IF;
END $$;

-- 3) Forecast table
create table if not exists public.parking_forecast (
  poi_id uuid not null references public.pois(id) on delete cascade,
  dow smallint not null check (dow between 0 and 6),
  hour smallint not null check (hour between 0 and 23),
  p_open numeric(4,3) not null default 0.33,
  p_some numeric(4,3) not null default 0.33,
  p_full numeric(4,3) not null default 0.34,
  eta_80pct interval null,
  updated_at timestamptz not null default now(),
  primary key (poi_id, dow, hour)
);

alter table public.parking_forecast enable row level security;
drop policy if exists parking_forecast_read_all on public.parking_forecast;
create policy parking_forecast_read_all on public.parking_forecast for select to authenticated using (true);

-- 4) Fusion functions (Dirichlet-like with decay)
create or replace function public.fuse_parking_state(p_poi_id uuid, p_half_life_min int default 30, p_now timestamptz default now())
returns public.parking_state
language plpgsql security definer as $$
declare
  a_open double precision := 0.001;
  a_some double precision := 0.001;
  a_full double precision := 0.001;
  win int := 45; r record; top text := 'unknown'; conf double precision := 0.4; sumw double precision;
begin
  for r in
    select status, trust_snapshot, ts, coalesce((payload->>'source')::text,'crowd') src
    from public.poi_reports
    where poi_id=p_poi_id and kind='parking' and ts >= p_now - (win||' minutes')::interval
  loop
    declare age_min double precision := extract(epoch from (p_now-r.ts))/60.0;
    declare decay   double precision := power(0.5, age_min / p_half_life_min);
    declare basew   double precision := case when r.src='operator' then 1.0 else greatest(r.trust_snapshot,0.2) end;
    declare w       double precision := basew*decay;
    begin
      if r.status='open' then a_open:=a_open+w;
      elsif r.status='some' then a_some:=a_some+w;
      elsif r.status='full' then a_full:=a_full+w;
      end if;
    end;
  end loop;
  sumw:=a_open+a_some+a_full;
  if sumw>0 then
    if a_open>=a_some and a_open>=a_full then top:='open';
    elsif a_some>=a_open and a_some>=a_full then top:='some';
    else top:='full'; end if;
    conf:=greatest(a_open, greatest(a_some,a_full))/sumw;
  end if;
  insert into public.parking_state(poi_id,occupancy,confidence,last_update,source_mix)
  values(p_poi_id, top, conf, p_now, jsonb_build_object('alpha',jsonb_build_object('open',a_open,'some',a_some,'full',a_full)))
  on conflict (poi_id) do update
    set occupancy=excluded.occupancy, confidence=excluded.confidence, last_update=excluded.last_update, source_mix=excluded.source_mix
  returning * into r;
  return r;
end $$;

create or replace function public.fuse_weigh_state(p_poi_id uuid, p_half_life_min int default 30, p_now timestamptz default now())
returns public.weigh_station_state
language plpgsql security definer as $$
declare
  a_open double precision := 0.001;
  a_closed double precision := 0.001;
  a_bypass double precision := 0.001;
  win int := 45; r record; top text := 'unknown'; conf double precision := 0.4; sumw double precision;
begin
  for r in
    select status, trust_snapshot, ts, coalesce((payload->>'source')::text,'crowd') src
    from public.poi_reports
    where poi_id=p_poi_id and kind='weigh' and ts >= p_now - (win||' minutes')::interval
  loop
    declare age_min double precision := extract(epoch from (p_now-r.ts))/60.0;
    declare decay   double precision := power(0.5, age_min / p_half_life_min);
    declare basew   double precision := case when r.src='operator' then 1.0 else greatest(r.trust_snapshot,0.2) end;
    declare w       double precision := basew*decay;
    begin
      if r.status='open' then a_open:=a_open+w;
      elsif r.status='closed' then a_closed:=a_closed+w;
      elsif r.status='bypass' then a_bypass:=a_bypass+w;
      end if;
    end;
  end loop;
  sumw:=a_open+a_closed+a_bypass;
  if sumw>0 then
    if a_open=greatest(a_open, greatest(a_closed,a_bypass)) then top:='open';
    elsif a_closed=greatest(a_open, greatest(a_closed,a_bypass)) then top:='closed';
    else top:='bypass'; end if;
    conf:=greatest(a_open, greatest(a_closed,a_bypass))/sumw;
  end if;
  insert into public.weigh_station_state(poi_id,status,confidence,last_update,source_mix)
  values(p_poi_id, top, conf, p_now, jsonb_build_object('alpha',jsonb_build_object('open',a_open,'closed',a_closed,'bypass',a_bypass)))
  on conflict (poi_id) do update
    set status=excluded.status, confidence=excluded.confidence, last_update=excluded.last_update, source_mix=excluded.source_mix
  returning * into r;
  return r;
end $$;

revoke all on function public.fuse_parking_state(uuid,int,timestamptz) from public;
revoke all on function public.fuse_weigh_state(uuid,int,timestamptz) from public;
grant execute on function public.fuse_parking_state(uuid,int,timestamptz) to service_role;
grant execute on function public.fuse_weigh_state(uuid,int,timestamptz) to service_role;

-- 5) BBox RPCs (earthdistance)
create or replace function public.state_parking_in_bbox(
  w double precision, s double precision, e double precision, n double precision, min_conf numeric default 0
) returns table (
  poi_id uuid, name text, lat double precision, lng double precision, occupancy text, confidence numeric, last_update timestamptz
)
language sql security definer as $$
  select p.id, p.name, p.lat, p.lng, ps.occupancy, ps.confidence, ps.last_update
  from public.pois p
  join public.parking_state ps on ps.poi_id=p.id
  where earth_box(ll_to_earth((s+n)/2.0,(w+e)/2.0),
        greatest(earth_distance(ll_to_earth(s,w),ll_to_earth(s,e)),
                 earth_distance(ll_to_earth(s,w),ll_to_earth(n,w)))) @> ll_to_earth(p.lat,p.lng)
    and ps.confidence >= min_conf
$$;

create or replace function public.state_weigh_in_bbox(
  w double precision, s double precision, e double precision, n double precision, min_conf numeric default 0
) returns table (
  poi_id uuid, name text, lat double precision, lng double precision, status text, confidence numeric, last_update timestamptz
)
language sql security definer as $$
  select p.id, p.name, p.lat, p.lng, ws.status, ws.confidence, ws.last_update
  from public.pois p
  join public.weigh_station_state ws on ws.poi_id=p.id
  where earth_box(ll_to_earth((s+n)/2.0,(w+e)/2.0),
        greatest(earth_distance(ll_to_earth(s,w),ll_to_earth(s,e)),
                 earth_distance(ll_to_earth(s,w),ll_to_earth(n,w)))) @> ll_to_earth(p.lat,p.lng)
    and ws.confidence >= min_conf
$$;

revoke all on function public.state_parking_in_bbox(double precision,double precision,double precision,double precision,numeric) from public;
revoke all on function public.state_weigh_in_bbox(double precision,double precision,double precision,double precision,numeric) from public;
grant execute on function public.state_parking_in_bbox(double precision,double precision,double precision,double precision,numeric) to authenticated, anon;
grant execute on function public.state_weigh_in_bbox(double precision,double precision,double precision,double precision,numeric) to authenticated, anon;

-- 6) Naive forecast backfill seed
with hourly as (
  select poi_id,
         extract(dow from last_update)::int as dow,
         extract(hour from last_update)::int as hour,
         occupancy
  from public.parking_state
  union all
  select poi_id,
         extract(dow from ts)::int as dow,
         extract(hour from ts)::int as hour,
         status
  from public.poi_reports
  where kind='parking' and ts >= now() - interval '42 days'
),
agg as (
  select poi_id,dow,hour,
    avg((occupancy='open')::int)::numeric as p_open,
    avg((occupancy='some')::int)::numeric as p_some,
    avg((occupancy='full')::int)::numeric as p_full
  from hourly group by 1,2,3
)
insert into public.parking_forecast(poi_id,dow,hour,p_open,p_some,p_full,updated_at)
select poi_id,dow,hour,
       coalesce(nullif(round(p_open,3),0),0.33),
       coalesce(nullif(round(p_some,3),0),0.33),
       coalesce(nullif(round(p_full,3),0),0.34),
       now()
from agg
on conflict (poi_id,dow,hour) do update
set p_open=excluded.p_open, p_some=excluded.p_some, p_full=excluded.p_full, updated_at=excluded.updated_at;
