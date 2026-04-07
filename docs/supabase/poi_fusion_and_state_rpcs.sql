-- docs/supabase/poi_fusion_and_state_rpcs.sql
-- Purpose: Add fusion functions (Dirichlet-like with decay) and state RPCs for bbox queries.
-- Safe to re-run: uses CREATE OR REPLACE for functions and revokes/grants guarded by existence checks where applicable.

-- 0) Spatial helpers
create extension if not exists cube;
create extension if not exists earthdistance;

-- 1) Fusion functions (parking and weigh)
-- Notes:
-- - SECURITY DEFINER so service_role can execute regardless of caller RLS.
-- - Assumes public.poi_reports exists with columns (poi_id, kind, status, trust_snapshot, ts, payload jsonb).
-- - Writes into public.parking_state / public.weigh_station_state (tables ensured elsewhere in repo).

create or replace function public.fuse_parking_state(
  p_poi_id uuid,
  p_half_life_min int default 30,
  p_now timestamptz default now()
) returns public.parking_state
language plpgsql
security definer
as $$
declare
  v_alpha_open  double precision := 0.001;
  v_alpha_some  double precision := 0.001;
  v_alpha_full  double precision := 0.001;
  v_window_min  int := 45;
  r record;
  v_sum double precision;
  v_top text := 'unknown';
  v_conf double precision := 0.4;
  v_mix jsonb := '{}'::jsonb;
begin
  for r in
    select status, trust_snapshot, ts, coalesce((payload->>'source')::text,'crowd') as src
    from public.poi_reports
    where poi_id = p_poi_id and kind = 'parking' and ts >= p_now - (v_window_min || ' minutes')::interval
  loop
    declare
      v_age_min double precision := extract(epoch from (p_now - r.ts))/60.0;
      v_decay double precision := power(0.5, v_age_min / p_half_life_min);
      v_base double precision := case when r.src = 'operator' then 1.0 else greatest(r.trust_snapshot, 0.2) end;
      v_w double precision := v_base * v_decay;
      v_prev double precision := coalesce((v_mix->>coalesce(r.src,'crowd'))::double precision, 0);
    begin
      if r.status = 'open' then v_alpha_open := v_alpha_open + v_w;
      elsif r.status = 'some' then v_alpha_some := v_alpha_some + v_w;
      elsif r.status = 'full' then v_alpha_full := v_alpha_full + v_w;
      end if;
      v_mix := v_mix || jsonb_build_object(coalesce(r.src,'crowd'), v_prev + v_w);
    end;
  end loop;

  v_sum := v_alpha_open + v_alpha_some + v_alpha_full;
  if v_sum > 0 then
    if v_alpha_open >= v_alpha_some and v_alpha_open >= v_alpha_full then v_top := 'open';
    elsif v_alpha_some >= v_alpha_open and v_alpha_some >= v_alpha_full then v_top := 'some';
    else v_top := 'full';
    end if;
    v_conf := greatest(v_alpha_open, greatest(v_alpha_some, v_alpha_full)) / v_sum;
  end if;

  insert into public.parking_state as ps (poi_id, occupancy, confidence, last_update, source_mix)
  values (p_poi_id, v_top, v_conf, p_now, jsonb_build_object('alpha', jsonb_build_object('open',v_alpha_open,'some',v_alpha_some,'full',v_alpha_full),'mix',v_mix))
  on conflict (poi_id) do update
  set occupancy = excluded.occupancy,
      confidence = excluded.confidence,
      last_update = excluded.last_update,
      source_mix = excluded.source_mix
  returning * into r;

  return r;
end $$;

create or replace function public.fuse_weigh_state(
  p_poi_id uuid,
  p_half_life_min int default 30,
  p_now timestamptz default now()
) returns public.weigh_station_state
language plpgsql
security definer
as $$
declare
  v_alpha_open  double precision := 0.001;
  v_alpha_closed double precision := 0.001;
  v_alpha_bypass double precision := 0.001;
  v_window_min  int := 45;
  r record;
  v_sum double precision;
  v_top text := 'unknown';
  v_conf double precision := 0.4;
begin
  for r in
    select status, trust_snapshot, ts, coalesce((payload->>'source')::text,'crowd') as src
    from public.poi_reports
    where poi_id = p_poi_id and kind = 'weigh' and ts >= p_now - (v_window_min || ' minutes')::interval
  loop
    declare
      v_age_min double precision := extract(epoch from (p_now - r.ts))/60.0;
      v_decay double precision := power(0.5, v_age_min / p_half_life_min);
      v_base double precision := case when r.src = 'operator' then 1.0 else greatest(r.trust_snapshot, 0.2) end;
      v_w double precision := v_base * v_decay;
    begin
      if r.status = 'open' then v_alpha_open := v_alpha_open + v_w;
      elsif r.status = 'closed' then v_alpha_closed := v_alpha_closed + v_w;
      elsif r.status = 'bypass' then v_alpha_bypass := v_alpha_bypass + v_w;
      end if;
    end;
  end loop;

  v_sum := v_alpha_open + v_alpha_closed + v_alpha_bypass;
  if v_sum > 0 then
    if v_alpha_open = greatest(v_alpha_open, greatest(v_alpha_closed, v_alpha_bypass)) then v_top := 'open';
    elsif v_alpha_closed = greatest(v_alpha_open, greatest(v_alpha_closed, v_alpha_bypass)) then v_top := 'closed';
    else v_top := 'bypass';
    end if;
    v_conf := greatest(v_alpha_open, greatest(v_alpha_closed, v_alpha_bypass)) / v_sum;
  end if;

  insert into public.weigh_station_state as ws (poi_id, status, confidence, last_update, source_mix)
  values (p_poi_id, v_top, v_conf, p_now, jsonb_build_object('alpha', jsonb_build_object('open',v_alpha_open,'closed',v_alpha_closed,'bypass',v_alpha_bypass)))
  on conflict (poi_id) do update
  set status = excluded.status,
      confidence = excluded.confidence,
      last_update = excluded.last_update,
      source_mix = excluded.source_mix
  returning * into r;

  return r;
end $$;

-- Guard grants: service_role should execute these fusion functions
revoke all on function public.fuse_parking_state(uuid,int,timestamptz) from public;
revoke all on function public.fuse_weigh_state(uuid,int,timestamptz) from public;
grant execute on function public.fuse_parking_state(uuid,int,timestamptz) to service_role;
grant execute on function public.fuse_weigh_state(uuid,int,timestamptz) to service_role;

-- 2) State RPCs for bbox reads (parking & weigh)
create or replace function public.state_parking_in_bbox(
  w double precision, s double precision, e double precision, n double precision, min_conf numeric default 0
) returns table (
  poi_id uuid, name text, lat double precision, lng double precision,
  occupancy text, confidence numeric, last_update timestamptz
)
language sql
security definer
as $$
  select p.id, p.name, p.lat, p.lng, ps.occupancy, ps.confidence, ps.last_update
  from public.pois p
  join public.parking_state ps on ps.poi_id = p.id
  where earth_box(ll_to_earth((s+n)/2.0, (w+e)/2.0), greatest(
          earth_distance(ll_to_earth(s, w), ll_to_earth(s, e)),
          earth_distance(ll_to_earth(s, w), ll_to_earth(n, w))
        )) @> ll_to_earth(p.lat, p.lng)
    and ps.confidence >= min_conf
$$;

create or replace function public.state_weigh_in_bbox(
  w double precision, s double precision, e double precision, n double precision, min_conf numeric default 0
) returns table (
  poi_id uuid, name text, lat double precision, lng double precision,
  status text, confidence numeric, last_update timestamptz
)
language sql
security definer
as $$
  select p.id, p.name, p.lat, p.lng, ws.status, ws.confidence, ws.last_update
  from public.pois p
  join public.weigh_station_state ws on ws.poi_id = p.id
  where earth_box(ll_to_earth((s+n)/2.0, (w+e)/2.0), greatest(
          earth_distance(ll_to_earth(s, w), ll_to_earth(s, e)),
          earth_distance(ll_to_earth(s, w), ll_to_earth(n, w))
        )) @> ll_to_earth(p.lat, p.lng)
    and ws.confidence >= min_conf
$$;

-- Revoke and grant execute for RPCs
revoke all on function public.state_parking_in_bbox(double precision,double precision,double precision,double precision,numeric) from public;
revoke all on function public.state_weigh_in_bbox(double precision,double precision,double precision,double precision,numeric) from public;
grant execute on function public.state_parking_in_bbox(double precision,double precision,double precision,double precision,numeric) to authenticated, anon;
grant execute on function public.state_weigh_in_bbox(double precision,double precision,double precision,double precision,numeric) to authenticated, anon;

-- 3) Tiny backfill SQL block for initial forecast (optional manual run)
-- See separate scheduled function cron.parking_forecast_rollup implemented in this repo.
-- Provided here for convenience when seeding environments with minimal data.
--
-- with hourly as (
--   select
--     ps.poi_id,
--     extract(dow from ps.last_update)::int as dow,
--     extract(hour from ps.last_update)::int as hour,
--     ps.occupancy
--   from public.parking_state ps
--   union all
--   select
--     pr.poi_id,
--     extract(dow from pr.ts)::int as dow,
--     extract(hour from pr.ts)::int as hour,
--     pr.status as occupancy
--   from public.poi_reports pr
--   where pr.kind = 'parking' and pr.ts >= now() - interval '42 days'
-- ),
-- agg as (
--   select poi_id, dow, hour,
--     avg(case when occupancy='open' then 1.0 else 0.0 end)::numeric as p_open,
--     avg(case when occupancy='some' then 1.0 else 0.0 end)::numeric as p_some,
--     avg(case when occupancy='full' then 1.0 else 0.0 end)::numeric as p_full
--   from hourly
--   group by 1,2,3
-- )
-- insert into public.parking_forecast (poi_id, dow, hour, p_open, p_some, p_full, updated_at)
-- select poi_id, dow, hour,
--        coalesce(nullif(round(p_open::numeric,3),0), 0.33),
--        coalesce(nullif(round(p_some::numeric,3),0), 0.33),
--        coalesce(nullif(round(p_full::numeric,3),0), 0.34),
--        now()
-- from agg
-- on conflict (poi_id, dow, hour) do update
-- set p_open = excluded.p_open,
--     p_some = excluded.p_some,
--     p_full = excluded.p_full,
--     updated_at = excluded.updated_at;

-- End of file
