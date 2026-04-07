-- Quotas & soft/hard limits (stop runaway spend)

create table if not exists public.usage_quotas (
  org_id uuid not null,
  feature_key text not null,
  soft_limit bigint,  -- warn
  hard_limit bigint,  -- block
  period_start date not null default date_trunc('month', now())::date,
  primary key (org_id, feature_key, period_start)
);

-- Fast check before metering insert
create or replace function public.usage_may_consume(p_org uuid, p_feature text, p_units int)
returns table(allowed boolean, reason text)
language sql stable as $$
  with cur as (
    select coalesce(sum(units),0) as used
    from public.usage_events
    where org_id = p_org
      and feature_key = p_feature
      and date_trunc('month', at) = date_trunc('month', now())
  ), q as (
    select soft_limit, hard_limit
    from public.usage_quotas
    where org_id = p_org
      and feature_key = p_feature
      and period_start = date_trunc('month', now())::date
  )
  select
    case
      when (select hard_limit from q) is not null and (select used from cur)+p_units > (select hard_limit from q) then false
      else true
    end as allowed,
    case
      when (select hard_limit from q) is not null and (select used from cur)+p_units > (select hard_limit from q) then 'hard_limit_exceeded'
      when (select soft_limit from q) is not null and (select used from cur)+p_units > (select soft_limit from q) then 'soft_limit_exceeded'
      else 'ok'
    end as reason;
$$;

-- Usage: if allowed=false -> return 402/429; if soft_limit_exceeded -> send one daily alert per org/feature
