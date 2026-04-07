-- 20250928_refresh_safety_summary.sql
-- Adds daily safety summary, CSV export view, corridor risk rollups, and refresh functions.
-- Adjusted to current schema: public.safety_alerts (lat/lng numeric, alert_type enum, severity int 1..5, fired_at ts)

-- Daily safety summary table (per org/day)
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

-- CSV export view adapted to safety_alerts
create or replace view public.v_export_alerts as
select
  a.id,
  a.org_id,
  a.driver_id,
  a.source,
  a.alert_type::text as event_type,
  null::text as title,
  a.message,
  a.severity::text as severity,
  a.lng as lon,
  a.lat as lat,
  null::jsonb as context,
  a.fired_at as created_at
from public.safety_alerts a;

-- Optional: grants for PostgREST access (RLS on base table still applies)
alter view public.v_export_alerts owner to postgres;
grant select on public.v_export_alerts to anon, authenticated;

-- Corridor risk rollups (grid cells over points)
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

-- Refresh function: build summaries from safety_alerts
create or replace function public.refresh_safety_summary(p_org uuid default null, p_days int default 7)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  d date;
  org uuid;
begin
  -- Rebuild daily summaries for the last p_days
  for d in select generate_series((current_date - (p_days::int - 1)), current_date, interval '1 day')::date loop
    for org in
      select distinct org_id from public.safety_alerts
      where (p_org is null or org_id = p_org)
        and fired_at >= d::timestamptz
        and fired_at < (d + 1)::timestamptz
    loop
      insert into public.safety_daily_summary as s (org_id, summary_date, total_alerts, urgent_alerts, unique_drivers, top_types, updated_at)
      select
        org,
        d,
        count(*)::int as total_alerts,
        count(*) filter (where severity >= 4)::int as urgent_alerts,
        count(distinct driver_id)::int as unique_drivers,
        (
          select coalesce(jsonb_agg(t order by t.ct desc), '[]'::jsonb)
          from (
            select alert_type::text as type, count(*)::int as ct
            from public.safety_alerts
            where org_id = org
              and fired_at >= d::timestamptz
              and fired_at < (d + 1)::timestamptz
            group by alert_type
            order by count(*) desc
            limit 5
          ) t
        ) as top_types,
        now()
      on conflict (org_id, summary_date) do update
      set total_alerts = excluded.total_alerts,
          urgent_alerts = excluded.urgent_alerts,
          unique_drivers = excluded.unique_drivers,
          top_types = excluded.top_types,
          updated_at = now();
    end loop;
  end loop;

  -- Recompute corridor risk cells using 0.05 degree grid for last 30 days
  delete from public.risk_corridor_cells where (p_org is null or org_id = p_org);

  insert into public.risk_corridor_cells (org_id, cell, alert_count, urgent_count, types, updated_at)
  with recent as (
    select org_id,
           alert_type::text as type,
           severity,
           st_setsrid(st_makepoint(lng, lat), 4326) as geom
    from public.safety_alerts
    where fired_at >= now() - interval '30 days'
      and lat is not null and lng is not null
      and (p_org is null or org_id = p_org)
  ), grid as (
    select org_id,
           st_snaptogrid(geom, 0.05, 0.05) as g,
           type,
           severity
    from recent
  ), leaf as (
    select org_id, g as geom, type, severity
    from grid
  ), agg as (
    select
      org_id,
      st_envelope(st_collect(geom)) as cell_geom,
      count(*) as alert_count,
      count(*) filter (where severity >= 4) as urgent_count,
      jsonb_agg(jsonb_build_object('type', type, 'count', cnt)) as types
    from (
      select org_id, geom, type, count(*) as cnt, max(severity) as severity
      from leaf
      group by org_id, geom, type
    ) t
    group by org_id, st_envelope(st_collect(geom))
  )
  select
    org_id,
    st_envelope(cell_geom)::geometry(Polygon,4326) as cell,
    alert_count::int,
    urgent_count::int,
    coalesce(types, '[]'::jsonb) as types,
    now()
  from agg;
end $$;

revoke all on function public.refresh_safety_summary(uuid,int) from public;
grant execute on function public.refresh_safety_summary(uuid,int) to service_role;

-- Convenience wrapper for anon/auth clients (expects header x-app-org-id)
create or replace function public.refresh_safety_summary_for_me()
returns void
language plpgsql
security definer
as $$
declare
  hdr jsonb;
  org text;
begin
  hdr := to_jsonb(current_setting('request.headers', true));
  begin
    org := (hdr->>'x-app-org-id');
  exception when others then
    org := null;
  end;
  perform public.refresh_safety_summary(nullif(org, '')::uuid, 7);
end $$;

revoke all on function public.refresh_safety_summary_for_me() from public;
grant execute on function public.refresh_safety_summary_for_me() to authenticated, anon;
