-- Quarterly effectiveness view + materialized table and refresh RPC
-- Apply in Supabase SQL editor or via CLI. Safe to run multiple times.

-- Logical view
create or replace view public.v_alert_effectiveness_qtr as
select
  org_id,
  date_trunc('quarter', triggered_at) as quarter,
  code,
  count(*) as alerts,
  avg(extract(epoch from (acknowledged_at - triggered_at))/60.0) filter (where acknowledged) as mtta_min,
  avg(extract(epoch from (resolved_at - triggered_at))/60.0) filter (where resolved_at is not null) as mttr_min,
  sum((remediation_clicked)::int) as remediation_clicks
from public.alerts_events
group by org_id, date_trunc('quarter', triggered_at), code;

-- Materialized storage (upsert target)
create table if not exists public.alert_effectiveness_qtr_mat (
  org_id uuid not null,
  quarter date not null,
  code text not null,
  alerts int not null,
  mtta_min numeric,
  mttr_min numeric,
  remediation_clicks int not null default 0,
  generated_at timestamptz not null default now(),
  primary key (org_id, quarter, code)
);

create index if not exists idx_alert_eff_qtr_org_time on public.alert_effectiveness_qtr_mat (org_id, quarter desc);

-- Refresh RPC (SECURITY DEFINER)
create or replace function public.fn_refresh_alert_effectiveness_qtr_mat()
returns table (rows int)
language sql
security definer
as $$
  with src as (
    select org_id, quarter::date, code, alerts, mtta_min, mttr_min, remediation_clicks
    from public.v_alert_effectiveness_qtr
  ), up as (
    insert into public.alert_effectiveness_qtr_mat (org_id, quarter, code, alerts, mtta_min, mttr_min, remediation_clicks, generated_at)
    select org_id, quarter, code, alerts, mtta_min, mttr_min, remediation_clicks, now()
    from src
    on conflict (org_id, quarter, code) do update
      set alerts = excluded.alerts,
          mtta_min = excluded.mtta_min,
          mttr_min = excluded.mttr_min,
          remediation_clicks = excluded.remediation_clicks,
          generated_at = excluded.generated_at
    returning 1
  )
  select count(*) from up;
$$;

revoke all on function public.fn_refresh_alert_effectiveness_qtr_mat() from public;
grant execute on function public.fn_refresh_alert_effectiveness_qtr_mat() to service_role;
