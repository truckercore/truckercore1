-- 20250924_hazards_hardening.sql
-- Purpose: Hardening and mobile-optimized access for unified hazards overlay.
-- Changes:
--  - Add ext_id and center columns
--  - Dedup unique index on (source, ext_id, starts_at)
--  - Retention helper prune_hazards(days)
--  - Normalization map (hazard_type_map)
--  - Update v_hazards_recent to expose normalized kind/severity
--  - Safer hazards_upsert_geojson RPC (validity, simplify, Feature support)
--  - Add hazards_in_bbox(bbox,max_rows) thin RPC
-- Idempotent and safe to re-run.

create extension if not exists postgis;

-- 1) Columns for dedup + query perf (nullable, added if missing)
alter table if exists public.hazards
  add column if not exists ext_id text,
  add column if not exists center geometry(Point,4326);

-- 2) Dedup index (one row per (source, ext_id, start time) when available)
create unique index if not exists hazards_ext_src_start_uniq
  on public.hazards (source, ext_id, starts_at)
  where ext_id is not null and starts_at is not null;

-- 3) Retention: prune older than N days (default 30)
create or replace function public.prune_hazards(days int default 30)
returns void
language plpgsql
as $$
begin
  delete from public.hazards
  where coalesce(ends_at, observed_at) < now() - make_interval(days => days);
end $$;

-- 4) Normalization map (for consistent UI)
create table if not exists public.hazard_type_map (
  source text not null,
  raw_category text not null,
  normalized text not null,   -- 'closure','restriction','weather','accident','other'
  severity int not null,      -- 1..4
  primary key (source, raw_category)
);

-- 5) Refresh view to surface normalized kind + severity (int)
create or replace view public.v_hazards_recent as
select
  h.id,
  h.source,
  coalesce(m.normalized, h.kind) as kind,
  coalesce(m.severity,
           case lower(h.severity)
             when 'minor' then 1
             when 'moderate' then 2
             when 'major' then 3
             else null
           end) as severity,
  h.title,
  h.description,
  h.starts_at,
  h.ends_at,
  h.observed_at,
  st_asgeojson(h.geom)::jsonb as geojson,
  h.metadata
from public.hazards h
left join public.hazard_type_map m
  on m.source = h.source and m.raw_category = coalesce(h.kind, (h.metadata->>'category'))
where h.observed_at >= now() - interval '7 days';

-- 6) Safer upsert RPC: accepts jsonb array or single GeoJSON Feature
create or replace function public.hazards_upsert_geojson(p_rows jsonb)
returns void language plpgsql security definer as $$
declare
  r jsonb;
  arr jsonb;
  feat jsonb;
  props jsonb;
  g geometry;
  g_center geometry(Point,4326);
begin
  -- Normalize input to an array of feature-like objects with properties/geometry
  if jsonb_typeof(p_rows) = 'array' then
    arr := p_rows;
  else
    -- Wrap single object into array
    arr := jsonb_build_array(p_rows);
  end if;

  for r in select * from jsonb_array_elements(arr) loop
    -- If caller sent a full GeoJSON Feature, lift properties/geometry
    if (r ? 'type') and lower(r->>'type') = 'feature' then
      feat := r;
      props := coalesce(feat->'properties','{}'::jsonb);
    else
      feat := r;
      -- Allow row-like payloads that already have top-level fields
      props := coalesce(r->'properties','{}'::jsonb);
    end if;

    -- Build geometry from either r.geom or r.geometry/Feature.geometry
    g := case
      when r ? 'geom' then ST_SetSRID(ST_GeomFromGeoJSON(r->>'geom'), 4326)
      when r ? 'geometry' then ST_SetSRID(ST_GeomFromGeoJSON(r->>'geometry'), 4326)
      when feat ? 'geometry' then ST_SetSRID(ST_GeomFromGeoJSON(feat->>'geometry'), 4326)
      else null
    end;

    if g is null then
      -- skip rows with no geometry
      continue;
    end if;

    if not ST_IsValid(g) then
      -- Try to make valid; if still invalid, skip
      g := ST_MakeValid(g);
      if not ST_IsValid(g) then
        continue;
      end if;
    end if;

    -- Simplify to ~50m tolerance to limit payload size
    g := ST_SimplifyPreserveTopology(g, 0.0005);
    g_center := ST_PointOnSurface(g);

    insert into public.hazards (id, source, kind, severity, title, description,
      geom, center, starts_at, ends_at, observed_at, metadata, ext_id)
    values (
      coalesce((r->>'id')::uuid, (props->>'id')::uuid, gen_random_uuid()),
      coalesce(r->>'source', props->>'source'),
      coalesce(r->>'kind', props->>'kind', props->>'event', 'other'),
      nullif(coalesce(r->>'severity', props->>'severity'),'')::text,
      nullif(coalesce(r->>'title', props->>'title', props->>'headline', props->>'event'),'')::text,
      nullif(coalesce(r->>'description', props->>'description', props->>'instruction'),'')::text,
      g,
      g_center,
      coalesce((r->>'starts_at')::timestamptz, (props->>'starts_at')::timestamptz, (props->>'onset')::timestamptz, (props->>'effective')::timestamptz),
      coalesce((r->>'ends_at')::timestamptz, (props->>'ends_at')::timestamptz, (props->>'expires')::timestamptz, (props->>'ends')::timestamptz),
      coalesce((r->>'observed_at')::timestamptz, (props->>'observed_at')::timestamptz, (props->>'sent')::timestamptz, now()),
      coalesce(r->'metadata', props, '{}'::jsonb),
      coalesce(r->>'ext_id', props->>'ext_id', props->>'id')
    )
    on conflict (id) do update
    set source = excluded.source,
        kind = excluded.kind,
        severity = excluded.severity,
        title = excluded.title,
        description = excluded.description,
        geom = excluded.geom,
        center = excluded.center,
        starts_at = excluded.starts_at,
        ends_at = excluded.ends_at,
        observed_at = excluded.observed_at,
        metadata = excluded.metadata,
        ext_id = excluded.ext_id;
  end loop;
end $$;

revoke all on function public.hazards_upsert_geojson(jsonb) from public;
grant execute on function public.hazards_upsert_geojson(jsonb) to service_role;

-- 7) Thin bbox RPC for mobile
create or replace function public.hazards_in_bbox(bbox geometry, max_rows int default 500)
returns table(
  id uuid,
  source text,
  kind text,
  severity int,
  starts_at timestamptz,
  ends_at timestamptz,
  geo jsonb
)
language sql
stable
as $$
  with norm as (
    select h.id, h.source,
           coalesce(m.normalized, h.kind) as kind,
           coalesce(m.severity,
                    case lower(h.severity)
                      when 'minor' then 1
                      when 'moderate' then 2
                      when 'major' then 3
                      else null
                    end) as severity,
           h.starts_at, h.ends_at, h.geom, h.center
    from public.hazards h
    left join public.hazard_type_map m
      on m.source = h.source and m.raw_category = coalesce(h.kind, (h.metadata->>'category'))
    where h.observed_at >= now() - interval '7 days'
  )
  select n.id, n.source, n.kind, n.severity, n.starts_at, n.ends_at,
         st_asgeojson(coalesce(n.center, st_pointonsurface(n.geom)))::jsonb as geo
  from norm n
  where st_intersects(n.geom, bbox)
  order by coalesce(n.ends_at, n.starts_at) desc
  limit max_rows
$$;

grant execute on function public.hazards_in_bbox(geometry,int) to anon, authenticated;
