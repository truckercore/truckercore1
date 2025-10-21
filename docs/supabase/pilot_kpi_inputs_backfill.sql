-- Pilot KPI inputs backfill helper (v1)
-- Location: docs/supabase/pilot_kpi_inputs_backfill.sql
-- Provides an optional function to backfill KPI inputs from existing events/audits.

-- Optional table to store normalized pilot KPI inputs (if not exists).
create table if not exists public.pilot_kpi_inputs (
  id bigserial primary key,
  org_id uuid not null,
  day date not null,
  proposed integer not null default 0,
  approved integer not null default 0,
  applied integer not null default 0,
  cph_uplift numeric,
  deadhead_saved_mi numeric,
  created_at timestamptz not null default now(),
  unique(org_id, day)
);

-- Function: derive and upsert last 14 days from autonomous_plan_events and load_metrics when present.
create or replace function public.fn_pilot_kpi_backfill_from_events()
returns void
language plpgsql
as $$
begin
  -- If required source tables are missing, exit gracefully
  if to_regclass('public.autonomous_plan_events') is null then
    return;
  end if;

  -- Upsert funnel counts
  insert into public.pilot_kpi_inputs(org_id, day, proposed, approved, applied)
  select org_id,
         (date_trunc('day', created_at))::date as day,
         count(*) filter (where action = 'proposed')::int as proposed,
         count(*) filter (where action = 'approved')::int as approved,
         count(*) filter (where action = 'applied')::int as applied
  from public.autonomous_plan_events
  where created_at >= now() - interval '90 days'
  group by org_id, (date_trunc('day', created_at))::date
  on conflict (org_id, day)
  do update set proposed = excluded.proposed,
                approved = excluded.approved,
                applied = excluded.applied;

  -- ROI metrics if load_metrics exists
  if to_regclass('public.load_metrics') is not null then
    update public.pilot_kpi_inputs p
    set cph_uplift = s.cph_uplift,
        deadhead_saved_mi = s.deadhead_saved_mi
    from (
      select org_id,
             (date_trunc('day', day))::date as day,
             avg(actual_cph - baseline_cph) as cph_uplift,
             avg(baseline_deadhead_mi - actual_deadhead_mi) as deadhead_saved_mi
      from public.load_metrics
      where day >= current_date - interval '90 days'
      group by org_id, (date_trunc('day', day))::date
    ) s
    where p.org_id = s.org_id and p.day = s.day;
  end if;
end;
$$;
