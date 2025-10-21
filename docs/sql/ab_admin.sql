-- =============================================================
-- A/B Admin: view + validated RPCs (create/update/pause/archive)
-- Safe to re-run (idempotent)
-- Depends on: public.ab_experiments, public.v_ab_results, public.feature_catalog
-- =============================================================

-- 1) Admin surface with live KPIs (last 30d)
-- Note: our v_ab_results already aggregates last 30d, so no ts filter is needed.
create or replace view public.v_ab_admin as
select
  e.key,
  e.feature_key,
  e.env,
  e.status,
  e.start_at,
  e.end_at,
  e.weights,
  coalesce(r.views,0)    as views_30d,
  coalesce(r.clicks,0)   as clicks_30d,
  coalesce(r.opens,0)    as opens_30d,
  coalesce(r.converts,0) as converts_30d,
  coalesce(r.ctr,0)::numeric(6,4)              as ctr_30d,
  coalesce(r.checkout_conv,0)::numeric(6,4)    as checkout_conv_30d,
  coalesce(r.end_to_end_conv,0)::numeric(6,4)  as e2e_conv_30d
from public.ab_experiments e
left join lateral (
  select
    sum(views)    as views,
    sum(clicks)   as clicks,
    sum(opens)    as opens,
    sum(converts) as converts,
    case when sum(views)  > 0 then sum(clicks)::numeric   / sum(views)  else 0 end as ctr,
    case when sum(opens)  > 0 then sum(converts)::numeric / sum(opens)  else 0 end as checkout_conv,
    case when sum(views)  > 0 then sum(converts)::numeric / sum(views)  else 0 end as end_to_end_conv
  from public.v_ab_results
  where exp_key = e.key
) r on true;

-- 2) RLS (read for admins; writes via RPC)
alter table public.ab_experiments enable row level security;
do $$
begin
  create policy ab_admin_ro on public.ab_experiments
  for select using (coalesce(current_setting('request.jwt.claims', true)::json->>'app_role','') in ('admin','fleet_admin'));
exception when duplicate_object then null; end $$;

-- 3) Validation helper (weights sum to 1, feature exists, dates ok)
create or replace function public.ab_validate(
  p_key text,
  p_feature_key text,
  p_weights jsonb,
  p_start timestamptz,
  p_end timestamptz
) returns void
language plpgsql
as $$
declare sumw numeric := 0;
begin
  if p_feature_key is null or p_feature_key = '' then
    raise exception 'feature_key required';
  end if;

  perform 1 from public.feature_catalog where key = p_feature_key;
  if not found then
    raise exception 'feature_key % not found', p_feature_key;
  end if;

  select coalesce(sum((value)::numeric),0) into sumw from jsonb_each_text(p_weights);
  if sumw <> 1 then
    raise exception 'weights must sum to 1. got %', sumw;
  end if;

  if p_end is not null and p_end <= p_start then
    raise exception 'end_at must be after start_at';
  end if;
end
$$;

-- 4) RPC: create experiment
create or replace function public.ab_admin_create(
  p_key text,
  p_feature_key text,
  p_env text default 'prod',
  p_start timestamptz default now(),
  p_end timestamptz default null,
  p_weights jsonb default '{"A":0.5,"B":0.5}'::jsonb
) returns text
language plpgsql
security definer
set search_path = public
as $$
begin
  if coalesce(current_setting('request.jwt.claims', true)::json->>'app_role','') not in ('admin','fleet_admin') then
    raise exception 'forbidden' using errcode='42501';
  end if;

  perform public.ab_validate(p_key, p_feature_key, p_weights, p_start, p_end);

  insert into public.ab_experiments(key, feature_key, env, start_at, end_at, weights, status)
  values (p_key, p_feature_key, p_env, p_start, p_end, p_weights, 'active')
  on conflict (key) do nothing;

  return p_key;
end
$$;

-- 5) RPC: update weights/dates/status (no destructive rebuild)
create or replace function public.ab_admin_update(
  p_key text,
  p_weights jsonb default null,
  p_end timestamptz default null,
  p_status text default null
) returns void
language plpgsql
security definer
set search_path = public
as $$
declare cur record; sumw numeric;
begin
  if coalesce(current_setting('request.jwt.claims', true)::json->>'app_role','') not in ('admin','fleet_admin') then
    raise exception 'forbidden' using errcode='42501';
  end if;

  select * into cur from public.ab_experiments where key = p_key;
  if not found then
    raise exception 'experiment % not found', p_key;
  end if;

  if p_weights is not null then
    select coalesce(sum((value)::numeric),0) into sumw from jsonb_each_text(p_weights);
    if sumw <> 1 then
      raise exception 'weights must sum to 1. got %', sumw;
    end if;
  end if;

  update public.ab_experiments
  set weights = coalesce(p_weights, weights),
      end_at  = coalesce(p_end, end_at),
      status  = coalesce(p_status, status)
  where key = p_key;
end
$$;

-- 6) RPC convenience: pause / archive
create or replace function public.ab_admin_pause(p_key text)
returns void
language sql
security definer
set search_path = public
as $$
  update public.ab_experiments set status='paused' where key = p_key;
$$;

create or replace function public.ab_admin_archive(p_key text)
returns void
language sql
security definer
set search_path = public
as $$
  update public.ab_experiments set status='archived' where key = p_key;
$$;

-- Grants for RPCs (authenticated callers)
revoke all on function public.ab_admin_create(text,text,text,timestamptz,timestamptz,jsonb) from public;
revoke all on function public.ab_admin_update(text,jsonb,timestamptz,text) from public;
revoke all on function public.ab_admin_pause(text) from public;
revoke all on function public.ab_admin_archive(text) from public;
grant execute on function public.ab_admin_create(text,text,text,timestamptz,timestamptz,jsonb) to authenticated, service_role;
grant execute on function public.ab_admin_update(text,jsonb,timestamptz,text) to authenticated, service_role;
grant execute on function public.ab_admin_pause(text) to authenticated, service_role;
grant execute on function public.ab_admin_archive(text) to authenticated, service_role;
