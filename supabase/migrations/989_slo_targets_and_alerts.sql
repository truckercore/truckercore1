-- 989_slo_targets_and_alerts.sql

-- 1) Targets table (availability + p95)
create table if not exists public.slo_targets (
  fn text primary key,
  avail_target numeric(5,4) not null default 0.999,  -- e.g., 99.9%
  p95_target_ms integer not null default 250,         -- e.g., 250ms
  enabled boolean not null default true,
  updated_at timestamptz not null default now()
);

-- seed sane defaults
insert into public.slo_targets (fn, avail_target, p95_target_ms, enabled)
values
  ('instant-pay', 0.999, 400, true),
  ('generate-ifta-report', 0.999, 600, true),
  ('optimizer', 0.999, 250, true)
on conflict (fn) do update
set avail_target = excluded.avail_target,
    p95_target_ms = excluded.p95_target_ms,
    enabled = excluded.enabled,
    updated_at = now();

-- 1.2 Error-budget burn views
-- Requires existing rolling views: public.slo_fn_rolling_1h, public.slo_fn_rolling_7d

create or replace view public.slo_burn_1h as
select r.fn,
       r.availability,
       t.avail_target,
       greatest(0, t.avail_target - r.availability) as burn,          -- portion over budget
       r.p95_ms, t.p95_target_ms,
       (r.p95_ms > t.p95_target_ms) as p95_breach
from public.slo_fn_rolling_1h r
join public.slo_targets t on t.fn=r.fn
where t.enabled;

create or replace view public.slo_burn_7d as
select r.fn,
       r.availability,
       t.avail_target,
       greatest(0, t.avail_target - r.availability) as burn,
       r.p95_ms, t.p95_target_ms,
       (r.p95_ms > t.p95_target_ms) as p95_breach
from public.slo_fn_rolling_7d r
join public.slo_targets t on t.fn=r.fn
where t.enabled;

-- 1.3 SLO alert emitter → alert_outbox
-- Requires existing table: public.alert_outbox(key text, payload jsonb, ...)

create or replace function public.check_slo_alerts()
returns void
language sql
security definer
set search_path=public
as $$
  with breaches as (
    select 'slo_breach_1h'::text as key, b.fn,
           jsonb_build_object(
             'window','1h','fn',b.fn,
             'availability', b.availability,
             'avail_target', b.avail_target,
             'p95_ms', b.p95_ms,
             'p95_target_ms', b.p95_target_ms
           ) as payload
    from public.slo_burn_1h b
    where b.availability < b.avail_target or b.p95_breach
    union all
    select 'slo_breach_7d', b.fn,
           jsonb_build_object(
             'window','7d','fn',b.fn,
             'availability', b.availability,
             'avail_target', b.avail_target,
             'p95_ms', b.p95_ms,
             'p95_target_ms', b.p95_target_ms
           )
    from public.slo_burn_7d b
    where b.availability < b.avail_target or b.p95_breach
  )
  insert into public.alert_outbox(key, payload)
  select key, payload from breaches;
$$;