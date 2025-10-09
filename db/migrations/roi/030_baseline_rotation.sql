begin;

alter table ai_roi_baselines
  add constraint if not exists ai_roi_baselines_snapshot_immutable
  check (snapshot_id is not null);

create or replace view v_fuel_price_volatility as
select
  org_id,
  'fuel_price_usd_per_gal'::text as key,
  stddev_samp(value)::numeric as stdev_7d
from ai_roi_baselines
where key='fuel_price_usd_per_gal' and effective_at > now()-interval '7 days'
group by org_id;

create table if not exists roi_baseline_rotation_cfg (
  key text primary key,
  threshold_delta numeric not null default 0.25,
  min_hours_between_snapshots int not null default 24
);

insert into roi_baseline_rotation_cfg(key)
values ('fuel_price_usd_per_gal')
on conflict (key) do nothing;

create or replace function roi_maybe_rotate_baseline(
  p_org uuid,
  p_key text,
  p_new_value numeric,
  p_comment text default 'auto-rotation'
) returns uuid
language plpgsql
security definer
as $$
declare
  last_ts timestamptz;
  last_val numeric;
  thresh numeric;
  minh int;
  sid uuid;
begin
  select value, effective_at into last_val, last_ts
  from ai_roi_baselines where org_id=p_org and key=p_key
  order by effective_at desc limit 1;

  select threshold_delta, min_hours_between_snapshots into thresh, minh
  from roi_baseline_rotation_cfg where key=p_key;

  if last_val is null then
    insert into ai_roi_baselines(org_id, key, value, comment)
    values (p_org, p_key, p_new_value, p_comment)
    returning snapshot_id into sid;
    return sid;
  end if;

  if abs(p_new_value - last_val) >= coalesce(thresh,0.25)
     and (now() - coalesce(last_ts, now()-interval '365 days')) >= make_interval(hours => coalesce(minh,24)) then
    insert into ai_roi_baselines(org_id, key, value, comment)
    values (p_org, p_key, p_new_value, p_comment)
    returning snapshot_id into sid;
    return sid;
  end if;

  return null;
end; $$;

commit;
