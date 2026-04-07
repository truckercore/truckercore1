begin;

create table if not exists public.ai_auto_promote_config (
  model_key text primary key,
  enabled boolean not null default true,
  step_pct int not null default 10 check (step_pct between 1 and 50),
  max_daily_steps int not null default 3 check (max_daily_steps between 1 and 12),
  blackout_start time,  -- e.g., 22:00
  blackout_end   time,  -- e.g., 04:00
  min_healthy_minutes int not null default 60
);

create or replace view public.ai_auto_promote_budget as
select
  model_key,
  count(*) filter (where action in ('start_canary','increase_canary','finish')
                   and created_at > now() - interval '24 hours') as steps_24h
from public.ai_promo_audit
group by 1;

commit;
