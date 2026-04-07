-- 20250930_roi_reports.sql
-- ROI report snapshots (quarterly) + RPC to generate
-- Idempotent and safe to re-run.

-- Enable required extension (for gen_random_uuid) if not present
create extension if not exists pgcrypto;

-- Table: safety_roi_reports
create table if not exists public.safety_roi_reports (
  id uuid primary key default gen_random_uuid(),
  org_id uuid not null,
  quarter_start date not null,
  quarter_end date not null,
  baseline_total_alerts int not null default 0,
  baseline_urgent_alerts int not null default 0,
  period_total_alerts int not null default 0,
  period_urgent_alerts int not null default 0,
  delta_pct numeric(6,2),
  top_corridors jsonb not null default '[]'::jsonb,
  insurance_note text,
  created_at timestamptz not null default now(),
  unique (org_id, quarter_start)
);
create index if not exists idx_roi_reports_org_q on public.safety_roi_reports (org_id, quarter_start desc);

-- RLS
alter table public.safety_roi_reports enable row level security;
create policy if not exists roi_reports_read on public.safety_roi_reports for select to authenticated
using (org_id::text = coalesce(current_setting('request.jwt.claims', true)::json->>'app_org_id',''));

-- RPC: generate ROI report for org
create or replace function public.generate_roi_report(p_org uuid, p_quarter_start date)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  q_end date := (p_quarter_start + interval '3 months' - interval '1 day')::date;
  baseline_start date := (p_quarter_start - interval '3 months')::date;
  baseline_end date := (p_quarter_start - interval '1 day')::date;
  b_total int; b_urgent int; p_total int; p_urgent int; delta numeric;
  rep_id uuid;
begin
  -- Baseline (previous quarter)
  begin
    select count(*), count(*) filter (where severity in ('HIGH','CRITICAL','URGENT','critical','urgent'))
    into b_total, b_urgent
    from public.alert_events
    where org_id = p_org
      and created_at >= baseline_start::timestamptz
      and created_at < (baseline_end + 1)::timestamptz;
  exception when undefined_table then
    b_total := 0; b_urgent := 0;
  end;

  -- Period (this quarter)
  begin
    select count(*), count(*) filter (where severity in ('HIGH','CRITICAL','URGENT','critical','urgent'))
    into p_total, p_urgent
    from public.alert_events
    where org_id = p_org
      and created_at >= p_quarter_start::timestamptz
      and created_at < (q_end + 1)::timestamptz;
  exception when undefined_table then
    p_total := 0; p_urgent := 0;
  end;

  delta := case when coalesce(b_total,0) = 0 then null else round(100.0 * (coalesce(p_total,0)::numeric - coalesce(b_total,0)::numeric) / nullif(b_total::numeric,0), 2) end;

  insert into public.safety_roi_reports (
    org_id, quarter_start, quarter_end,
    baseline_total_alerts, baseline_urgent_alerts,
    period_total_alerts, period_urgent_alerts,
    delta_pct,
    top_corridors,
    insurance_note,
    created_at
  ) values (
    p_org, p_quarter_start, q_end,
    coalesce(b_total, 0), coalesce(b_urgent, 0),
    coalesce(p_total, 0), coalesce(p_urgent, 0),
    delta,
    (select coalesce(jsonb_agg(t order by t.urgent_count desc), '[]'::jsonb)
     from (
       select id, urgent_count, alert_count
       from public.risk_corridor_cells
       where org_id = p_org
       order by urgent_count desc
       limit 5
     ) t),
    'Provide to your insurance carrier as evidence of proactive safety management.',
    now()
  ) on conflict (org_id, quarter_start) do update
    set period_total_alerts = excluded.period_total_alerts,
        period_urgent_alerts = excluded.period_urgent_alerts,
        delta_pct = excluded.delta_pct,
        top_corridors = excluded.top_corridors,
        created_at = now()
  returning id into rep_id;

  return rep_id;
end $$;

-- Grants
revoke all on function public.generate_roi_report(uuid,date) from public;
grant execute on function public.generate_roi_report(uuid,date) to service_role, authenticated;
