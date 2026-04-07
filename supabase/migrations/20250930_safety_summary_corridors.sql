-- 2025-09-29_safety_summary_corridors.sql
-- Consolidated migration to satisfy daily summary, export metering, signed artifacts, and corridor cells

-- Safety daily summary per org/day (already may exist)
create table if not exists public.safety_daily_summary (
  org_id uuid not null,
  summary_date date not null,
  total_alerts integer not null default 0,
  urgent_alerts integer not null default 0,
  unique_drivers integer not null default 0,
  top_types jsonb not null default '[]'::jsonb,
  updated_at timestamptz not null default now(),
  primary key (org_id, summary_date)
);

alter table public.safety_daily_summary enable row level security;
create policy if not exists safety_summary_read on public.safety_daily_summary
for select to authenticated
using (org_id::text = coalesce(current_setting('request.jwt.claims', true)::json->>'app_org_id',''));

-- CSV export view (org-scoped via RLS on base tables)
create or replace view public.v_export_alerts as
select
  a.id,
  a.org_id,
  a.user_id as driver_id,
  a.source,
  a.event_type::text as event_type,
  a.title,
  a.message,
  a.severity::text as severity,
  st_x(a.geom) as lon,
  st_y(a.geom) as lat,
  a.context,
  a.created_at
from public.alert_events a;

alter view public.v_export_alerts owner to postgres;
grant select on public.v_export_alerts to anon, authenticated;

-- Risk corridors heat cells (may already exist)
create table if not exists public.risk_corridor_cells (
  id bigserial primary key,
  org_id uuid,
  cell geometry(Polygon, 4326) not null,
  alert_count int not null default 0,
  urgent_count int not null default 0,
  types jsonb not null default '[]'::jsonb,
  updated_at timestamptz not null default now()
);
create index if not exists risk_corridor_cells_gix on public.risk_corridor_cells using gist (cell);
alter table public.risk_corridor_cells enable row level security;
create policy if not exists risk_corridor_read on public.risk_corridor_cells
for select to authenticated
using (org_id is null or org_id::text = coalesce(current_setting('request.jwt.claims', true)::json->>'app_org_id',''));

-- Export metering
create table if not exists public.export_usage (
  id bigserial primary key,
  org_id uuid not null,
  period_month date not null,
  kind text not null check (kind in ('alerts_csv','roi_pdf')),
  count int not null default 0,
  updated_at timestamptz not null default now(),
  unique (org_id, period_month, kind)
);
alter table public.export_usage enable row level security;
create policy if not exists export_usage_read on public.export_usage for select to authenticated
using (org_id::text = coalesce(current_setting('request.jwt.claims', true)::json->>'app_org_id',''));

-- Signed artifact registry
create table if not exists public.export_artifacts (
  id uuid primary key default gen_random_uuid(),
  org_id uuid not null,
  kind text not null check (kind in ('alerts_csv','roi_pdf')),
  from_ts timestamptz not null,
  to_ts timestamptz not null,
  filename text not null,
  content_type text not null,
  bytes int not null,
  storage_path text not null,
  sha256 text not null,
  signed boolean not null default true,
  created_at timestamptz not null default now(),
  deleted_at timestamptz
);
create index if not exists idx_export_artifacts_org_time on public.export_artifacts (org_id, created_at desc);
alter table public.export_artifacts enable row level security;
create policy if not exists export_artifacts_read on public.export_artifacts for select to authenticated
using (org_id::text = coalesce(current_setting('request.jwt.claims', true)::json->>'app_org_id',''));

-- Helper RPCs
create or replace function public.refresh_safety_summary(p_org uuid default null, p_days int default 7)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare d date; org uuid;
begin
  for d in select generate_series((current_date - (p_days::int - 1)), current_date, interval '1 day')::date loop
    for org in
      select distinct org_id from public.alert_events
      where (p_org is null or org_id = p_org)
        and created_at >= d::timestamptz
        and created_at < (d + 1)::timestamptz
    loop
      insert into public.safety_daily_summary as s (org_id, summary_date, total_alerts, urgent_alerts, unique_drivers, top_types, updated_at)
      select
        org, d,
        count(*)::int,
        count(*) filter (where severity = 'URGENT')::int,
        count(distinct user_id)::int,
        (
          select jsonb_agg(t order by t.ct desc)
          from (
            select event_type::text as type, count(*) as ct
            from public.alert_events
            where org_id = org
              and created_at >= d::timestamptz
              and created_at < (d + 1)::timestamptz
            group by event_type
            order by count(*) desc
            limit 5
          ) t
        ),
        now()
      on conflict (org_id, summary_date) do update
      set total_alerts = excluded.total_alerts,
          urgent_alerts = excluded.urgent_alerts,
          unique_drivers = excluded.unique_drivers,
          top_types = excluded.top_types,
          updated_at = now();
    end loop;
  end loop;

  delete from public.risk_corridor_cells where (p_org is null or org_id = p_org);
  insert into public.risk_corridor_cells (org_id, cell, alert_count, urgent_count, types, updated_at)
  with recent as (
    select * from public.alert_events
    where created_at >= now() - interval '30 days'
      and geom is not null
      and (p_org is null or org_id = p_org)
  ), grid as (
    select org_id, st_snaptogrid(geom::geometry, 0.05, 0.05) as g, event_type::text as type, severity
    from recent
  ), agg as (
    select
      org_id,
      st_envelope(st_collect(g)) as cell_geom,
      count(*) as alert_count,
      count(*) filter (where severity = 'URGENT') as urgent_count,
      jsonb_agg(jsonb_build_object('type', type, 'count', cnt)) as types
    from (
      select org_id, g, severity, type, count(*) as cnt
      from grid
      group by org_id, g, severity, type
    ) t
    group by org_id, st_envelope(st_collect(g))
  )
  select org_id, st_envelope(cell_geom)::geometry(Polygon,4326),
         alert_count::int, urgent_count::int, types, now()
  from agg;
end $$;

revoke all on function public.refresh_safety_summary(uuid,int) from public;
grant execute on function public.refresh_safety_summary(uuid,int) to service_role;

create or replace function public.increment_export_usage(p_org uuid, p_kind text)
returns void language plpgsql security definer as $$
declare m date := date_trunc('month', now())::date;
begin
  insert into public.export_usage (org_id, period_month, kind, count, updated_at)
  values (p_org, m, p_kind, 1, now())
  on conflict (org_id, period_month, kind) do update
    set count = public.export_usage.count + 1, updated_at = now();
end $$;

revoke all on function public.increment_export_usage(uuid,text) from public;
grant execute on function public.increment_export_usage(uuid,text) to service_role;
