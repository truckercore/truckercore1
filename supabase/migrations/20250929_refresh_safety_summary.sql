-- Safety summary & corridor rollups

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

alter table public.v_export_alerts owner to postgres;
grant select on public.v_export_alerts to anon, authenticated;

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
  for d in select generate_series((current_date - (p_days::int - 1)), current_date, interval '1 day')::date loop
    for org in
      select distinct org_id from public.alert_events
      where (p_org is null or org_id = p_org)
        and created_at >= d::timestamptz
        and created_at < (d + 1)::timestamptz
    loop
      insert into public.safety_daily_summary as s (org_id, summary_date, total_alerts, urgent_alerts, unique_drivers, top_types, updated_at)
      select
        org,
        d,
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

  delete from public.risk_corridor_cells where (p_org is null or org_id = p_org);
  insert into public.risk_corridor_cells (org_id, cell, alert_count, urgent_count, types, updated_at)
  with recent as (
    select *
    from public.alert_events
    where created_at >= now() - interval '30 days'
      and geom is not null
      and (p_org is null or org_id = p_org)
  ), grid as (
    select
      r.org_id,
      st_snaptogrid(r.geom::geometry, 0.05, 0.05) as g,
      r.event_type::text as type,
      r.severity
    from recent r
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
  select
    org_id,
    st_envelope(cell_geom)::geometry(Polygon,4326),
    alert_count::int,
    urgent_count::int,
    types,
    now()
  from agg;
end $$;

revoke all on function public.refresh_safety_summary(uuid,int) from public;
grant execute on function public.refresh_safety_summary(uuid,int) to service_role;

create or replace function public.refresh_safety_summary_for_me()
returns void
language plpgsql
security definer
as $$
declare
  headers jsonb;
  org uuid;
begin
  select current_setting('request.headers', true)::jsonb into headers;
  if headers ? 'x-app-org-id' then
    begin
      org := (headers->>'x-app-org-id')::uuid;
      perform public.refresh_safety_summary(org, 7);
    exception when others then
      -- ignore malformed header
      null;
    end;
  end if;
end $$;

revoke all on function public.refresh_safety_summary_for_me() from public;
grant execute on function public.refresh_safety_summary_for_me() to authenticated, anon;

-- View/RPC to return corridor cells with GeoJSON for frontend
create or replace function public.risk_corridors_select(p_org uuid default null)
returns table (
  id bigint,
  org_id uuid,
  alert_count int,
  urgent_count int,
  types jsonb,
  cell text
)
language sql
stable
as $$
  select
    rc.id,
    rc.org_id,
    rc.alert_count,
    rc.urgent_count,
    rc.types,
    st_asgeojson(rc.cell)::text as cell
  from public.risk_corridor_cells rc
  where (p_org is null or rc.org_id = p_org)
  order by rc.urgent_count desc, rc.alert_count desc
  limit 100
$$;

grant execute on function public.risk_corridors_select(uuid) to anon, authenticated;
