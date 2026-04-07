-- docs/supabase/truck_stop_scoring.sql
-- Scoring and confidence routines for Truck Stops
-- Apply after truck_stop_schema.sql. Requires pg_cron for periodic decay refresh.

create or replace function fn_time_decay(weight numeric, age_minutes numeric, half_life_minutes numeric)
returns numeric language sql immutable as $$
  select weight * power(0.5, greatest(age_minutes,0) / nullif(half_life_minutes,0));
$$;

-- Blend parking confidence from sources (operator=1.0, crowd=0.7, iot=1.1) with time decay (half-life 30m for crowd, 45m operator, 20m iot)
create or replace function fn_blend_parking_confidence(p_location uuid)
returns void language plpgsql as $$
declare
  now_ts timestamptz := now();
  c_operator numeric := 0;
  c_crowd numeric := 0;
  c_iot numeric := 0;
  last_update timestamptz := now_ts;
  age_min numeric;
  conf numeric;
begin
  -- latest operator
  select ps.confidence, ps.updated_at into c_operator, last_update
  from parking_status ps
  where ps.location_id = p_location and ps.source = 'operator'
  order by ps.updated_at desc limit 1;
  if c_operator is null then c_operator := 0; end if;
  age_min := extract(epoch from (now_ts - coalesce(last_update, now_ts))) / 60.0;
  c_operator := fn_time_decay(c_operator * 1.0, age_min, 45);

  -- latest crowd
  select ps.confidence, ps.updated_at into c_crowd, last_update
  from parking_status ps
  where ps.location_id = p_location and ps.source = 'crowd'
  order by ps.updated_at desc limit 1;
  if c_crowd is null then c_crowd := 0; end if;
  age_min := extract(epoch from (now_ts - coalesce(last_update, now_ts))) / 60.0;
  c_crowd := fn_time_decay(c_crowd * 0.7, age_min, 30);

  -- latest iot
  select ps.confidence, ps.updated_at into c_iot, last_update
  from parking_status ps
  where ps.location_id = p_location and ps.source = 'iot'
  order by ps.updated_at desc limit 1;
  if c_iot is null then c_iot := 0; end if;
  age_min := extract(epoch from (now_ts - coalesce(last_update, now_ts))) / 60.0;
  c_iot := fn_time_decay(c_iot * 1.1, age_min, 20);

  conf := greatest(0, least(1, c_operator + c_crowd + c_iot));

  insert into stop_confidence(location_id, metric, confidence, last_update)
  values (p_location, 'parking', conf, now_ts)
  on conflict (location_id) do update set confidence = excluded.confidence, last_update = excluded.last_update;
end; $$;

-- Compute stop score and factors json
create or replace function fn_compute_stop_score(p_location uuid)
returns void language plpgsql as $$
declare
  now_ts timestamptz := now();
  conf numeric := 0;
  diesel_cents int := null;
  discount_cents int := 0;
  effective numeric := null;
  factors jsonb;
  score numeric := 0;
begin
  select confidence into conf from stop_confidence where location_id = p_location;
  if conf is null then conf := 0; end if;

  select fp.diesel_cents, coalesce(fp.discount_cents,0) into diesel_cents, discount_cents
  from fuel_prices fp
  where fp.location_id = p_location
  order by fp.effective_at desc limit 1;
  if diesel_cents is not null then effective := diesel_cents - discount_cents; end if;

  -- Simple normalized fuel score: cheaper is better within recent neighborhood
  -- Compute median of latest prices across all locations to normalize
  with latest as (
    select distinct on (location_id) location_id, (diesel_cents - coalesce(discount_cents,0)) as eff
    from fuel_prices order by location_id, effective_at desc
  ), stats as (
    select percentile_cont(0.5) within group (order by eff) as med,
           percentile_cont(0.1) within group (order by eff) as p10,
           percentile_cont(0.9) within group (order by eff) as p90
    from latest
  )
  select case when effective is null then 0
              else greatest(0, least(1, ( (select med from stats) - effective) / nullif((select med from stats) - (select p10 from stats),0) )) end
  into strict effective; -- reuse variable for normalized fuel component

  factors := jsonb_build_object(
    'parking', conf,
    'fuel', coalesce(effective,0),
    'amenities', 0.6,
    'safety', 0.7,
    'detour', 0.9,
    'loyalty_boost', 0
  );

  -- Weighted sum
  score := 0.4*conf + 0.3*coalesce(effective,0) + 0.15*0.6 + 0.1*0.7 + 0.05*0.9;

  insert into stop_scores(location_id, score, factors, updated_at)
  values (p_location, score, factors, now_ts)
  on conflict (location_id) do update set score = excluded.score, factors = excluded.factors, updated_at = excluded.updated_at;
end; $$;

-- Trigger wrappers
create or replace function trg_after_parking_status()
returns trigger language plpgsql as $$
begin
  perform fn_blend_parking_confidence(new.location_id);
  perform fn_compute_stop_score(new.location_id);
  return new;
end; $$;

create or replace function trg_after_fuel_prices()
returns trigger language plpgsql as $$
begin
  perform fn_compute_stop_score(new.location_id);
  return new;
end; $$;

create or replace function trg_after_promotions()
returns trigger language plpgsql as $$
begin
  perform fn_compute_stop_score(coalesce(new.location_id, null));
  return new;
end; $$;

-- Attach triggers
drop trigger if exists t_parking_status_score on parking_status;
create trigger t_parking_status_score after insert on parking_status
for each row execute function trg_after_parking_status();

drop trigger if exists t_fuel_prices_score on fuel_prices;
create trigger t_fuel_prices_score after insert on fuel_prices
for each row execute function trg_after_fuel_prices();

-- Promotions changes may affect many locations; keep this simple for per-location promos
drop trigger if exists t_promotions_score on promotions;
create trigger t_promotions_score after insert or update on promotions
for each row when (new.location_id is not null) execute function trg_after_promotions();

-- Cron: periodic decay refresh (every 10 minutes)
create extension if not exists pg_cron;
select cron.schedule('stop_confidence_refresh', '*/10 * * * *', $$
  update stop_confidence sc set confidence = sub.conf, last_update = now()
  from (
    select l.location_id,
           (select fn_blend_parking_confidence(l.location_id), confidence from stop_confidence where location_id=l.location_id) as conf
    from locations l
  ) as sub
  where sc.location_id = sub.location_id;$$);
