-- Corridors RLS, bounded RPC, view, heartbeat, export audit

-- Helper to read org from JWT or proxy header
create or replace function public.current_org_id()
returns uuid
language sql stable
as $$
  select coalesce(
    nullif(current_setting('request.jwt.claims', true)::jsonb->>'org_id','')::uuid,
    nullif(current_setting('request.headers', true)::jsonb->>'x-app-org-id','')::uuid
  );
$$;

-- View that exposes corridors as GeoJSON. Some columns may be null if not present in base table.
create or replace view public.corridors_view as
select
  c.id,
  c.org_id,
  /* If name/notes/created_at columns don't exist in table, fallback to NULL/updated_at */
  null::text as name,
  c.risk_score,
  null::text as notes,
  c.updated_at,
  c.updated_at as created_at,
  st_asgeojson(c.geom)::jsonb as geojson
from public.corridors c;

alter view public.corridors_view owner to postgres;
grant select on public.corridors_view to anon, authenticated;

-- RPC: bounded corridors with pagination cursor (aligned to existing table: id is bigint, geom MultiLineString)
create or replace function public.rpc_corridors_bounded(
  p_org uuid,
  p_bbox text, -- "minLon,minLat,maxLon,maxLat"
  p_limit int default 200,
  p_cursor timestamptz default null
)
returns table (
  id bigint,
  org_id uuid,
  name text,
  risk_score numeric,
  notes text,
  updated_at timestamptz,
  created_at timestamptz,
  geojson jsonb
)
language plpgsql
security definer
set search_path = public
as $$
declare
  minlon double precision;
  minlat double precision;
  maxlon double precision;
  maxlat double precision;
  bbox geometry;
  my_org uuid;
begin
  my_org := coalesce(p_org, public.current_org_id());
  if p_bbox is null or length(p_bbox) < 5 then
    bbox := null;
  else
    minlon := split_part(p_bbox, ',', 1)::double precision;
    minlat := split_part(p_bbox, ',', 2)::double precision;
    maxlon := split_part(p_bbox, ',', 3)::double precision;
    maxlat := split_part(p_bbox, ',', 4)::double precision;
    bbox := st_makeenvelope(minlon, minlat, maxlon, maxlat, 4326);
  end if;

  return query
  select
    c.id,
    c.org_id,
    null::text as name,
    c.risk_score,
    null::text as notes,
    c.updated_at,
    c.updated_at as created_at,
    st_asgeojson(c.geom)::jsonb as geojson
  from public.corridors c
  where c.org_id = my_org
    and (bbox is null or st_intersects(c.geom, bbox))
    and (p_cursor is null or c.updated_at < p_cursor)
  order by c.updated_at desc
  limit greatest(1, least(p_limit, 1000));
end $$;

revoke all on function public.rpc_corridors_bounded(uuid,text,int,timestamptz) from public;
grant execute on function public.rpc_corridors_bounded(uuid,text,int,timestamptz) to authenticated, anon;

-- Heartbeat table to track scheduled refreshes
create table if not exists public.refresh_heartbeat (
  id bigserial primary key,
  job text not null,
  status text not null,
  ran_at timestamptz not null default now(),
  duration_ms integer,
  error text
);
create index if not exists refresh_heartbeat_job_idx on public.refresh_heartbeat (job, ran_at desc);

-- Export audit table
create table if not exists public.export_audit (
  id bigserial primary key,
  ts timestamptz not null default now(),
  user_id uuid,
  org_id uuid,
  route text not null,
  ok boolean not null,
  row_count int,
  export_id uuid
);
create index if not exists export_audit_ts_idx on public.export_audit (ts desc);
create index if not exists export_audit_org_idx on public.export_audit (org_id, ts desc);
