-- Ensure PostGIS
select postgis_full_version();

-- Corridors table (if not present); stores simplified corridor geometries and scores by org
create table if not exists public.corridors (
  id bigserial primary key,
  org_id uuid not null,
  geom geometry(MultiLineString, 4326) not null,
  risk_score numeric not null default 0,
  updated_at timestamptz not null default now()
);

create index if not exists corridors_org_idx on public.corridors(org_id);
create index if not exists corridors_gix on public.corridors using gist(geom);
create index if not exists corridors_risk_idx on public.corridors(risk_score desc);

alter table public.corridors enable row level security;

-- Use your org membership model to scope reads
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE schemaname = 'public' AND tablename = 'corridors' AND policyname = 'corridors same-org read'
  ) THEN
    CREATE POLICY "corridors same-org read"
    ON public.corridors FOR SELECT
    USING (
      org_id = (
        SELECT m.org_id
        FROM public.org_memberships m
        WHERE m.user_id = auth.uid() AND COALESCE(m.disabled_at, 'infinity') IS NULL
        LIMIT 1
      )
    );
  END IF;
END$$;

-- Heartbeats table for jobs
create table if not exists public.job_heartbeats(
  job text primary key,
  last_run timestamptz not null,
  ok boolean not null default true,
  message text
);

-- Risk corridor cells table for simple grid rollups (if not present)
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

-- Hardened GeoJSON RPC with bbox clip + simplify + limit + zoom adaptive
create or replace function public.risk_corridors_geojson(
  p_org_id uuid,
  p_minx double precision, p_miny double precision,
  p_maxx double precision, p_maxy double precision,
  p_limit int default 500,
  p_maxzoom int default 14
) returns jsonb
language sql
stable
security definer
set search_path = public
as $$
  with bounds as (
    select ST_MakeEnvelope(p_minx, p_miny, p_maxx, p_maxy, 4326) as env
  ),
  q as (
    select c.id, c.org_id,
           ST_SimplifyPreserveTopology(
             ST_Intersection(c.geom, bounds.env),
             case when p_maxzoom >= 14 then 0.0001 else 0.0008 end
           ) as g,
           c.risk_score, c.updated_at
    from public.corridors c, bounds
    where c.org_id = p_org_id
      and c.geom && bounds.env
      and ST_Intersects(c.geom, bounds.env)
    order by c.risk_score desc
    limit greatest(0, least(p_limit, 5000))
  )
  select jsonb_build_object(
    'type','FeatureCollection',
    'features', coalesce(jsonb_agg(
      jsonb_build_object(
        'type','Feature',
        'geometry', ST_AsGeoJSON(g)::jsonb,
        'properties', jsonb_build_object(
          'id', id,
          'risk_score', risk_score,
          'updated_at', updated_at
        )
      )
    ), '[]'::jsonb)
  )
  from q;
$$;

REVOKE ALL ON FUNCTION public.risk_corridors_geojson(uuid,double precision,double precision,double precision,double precision,int,int) FROM public;
GRANT EXECUTE ON FUNCTION public.risk_corridors_geojson(uuid,double precision,double precision,double precision,double precision,int,int) TO authenticated;

-- CSV export hardened view (masking + CSV injection guard)
create or replace function public._csv_guard(s text)
returns text language sql immutable as $$
  select case when s ~ '^[=\+\-@]' then '''' || s else s end
$$;

-- Assume base table public.alert_events exists; present masked view for export
create or replace view public.alerts_export_masked as
select
  a.id,
  a.org_id,
  a.created_at,
  a.event_type::text as type,
  a.severity::text as severity,
  public._csv_guard(coalesce(a.title,'')) as title,
  public._csv_guard(coalesce(a.message,'')) as message,
  st_x(a.geom) as lon,
  st_y(a.geom) as lat
from public.alert_events a
where a.org_id = (
  select m.org_id from public.org_memberships m
  where m.user_id = auth.uid() and COALESCE(m.disabled_at, 'infinity') IS NULL
  limit 1
);

ALTER VIEW public.alerts_export_masked OWNER TO postgres;
GRANT SELECT ON public.alerts_export_masked TO authenticated;

-- Hourly materialized view for corridors (to outgrow direct querying)
create materialized view if not exists public.mv_corridors_top as
select id, org_id, geom, risk_score, updated_at
from public.corridors
where risk_score > 0
with no data;

create index if not exists mv_corridors_top_gix on public.mv_corridors_top using gist(geom);
create index if not exists mv_corridors_top_org_idx on public.mv_corridors_top(org_id);
create index if not exists mv_corridors_top_risk_idx on public.mv_corridors_top(risk_score desc);

-- Refresh helper; SECURITY DEFINER to allow scheduler
create or replace function public.refresh_mv_corridors_top()
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  refresh materialized view concurrently public.mv_corridors_top;
  insert into public.job_heartbeats(job, last_run, ok, message)
  values ('refresh-mv-corridors-top', now(), true, 'ok')
  on conflict (job) do update
    set last_run = excluded.last_run, ok = excluded.ok, message = excluded.message;
end;
$$;

REVOKE ALL ON FUNCTION public.refresh_mv_corridors_top() FROM public;
GRANT EXECUTE ON FUNCTION public.refresh_mv_corridors_top() TO service_role, authenticated;

-- Minimal EXPLAIN harness RPC (returns text)
create or replace function public.explain_risk_corridors_geojson_sample()
returns text
language plpgsql
security definer
as $$
declare
  plan text;
begin
  execute $$ explain analyze
    select public.risk_corridors_geojson(
      gen_random_uuid(), -124.5, 32.5, -113.2, 42.1, 1000, 12
    ) $$ into plan;
  return plan;
end;
$$;

REVOKE ALL ON FUNCTION public.explain_risk_corridors_geojson_sample() FROM public;
GRANT EXECUTE ON FUNCTION public.explain_risk_corridors_geojson_sample() TO service_role;
