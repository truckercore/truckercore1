-- 20250924_hazards_migration_bundle.sql
-- Purpose: seed richer incident_type_map (DOT + NOAA), add hazards schema with SRID/indexes,
-- RPCs for upsert/bbox, retention/prune helpers, and monthly partitioning by observed_at.
-- Safe to re-run (IF NOT EXISTS checks) and compatible with existing schema in this repo.

-- 0) Requirements
create extension if not exists postgis;
create extension if not exists postgis_topology;

-- 1) Core tables

-- 1.1 Normalization map for provider categories -> normalized kind/severity
create table if not exists public.hazard_type_map (
  source text not null,
  raw_category text not null,
  normalized text not null default 'other',               -- legacy columns (compat)
  severity int not null default 1,                        -- legacy columns (compat)
  -- New richer mapping columns per spec
  norm_kind text null check (norm_kind in ('weather','traffic','closure','construction','incident','flood','wind','ice','fog','fire','other')),
  norm_severity smallint null check (norm_severity between 0 and 5),
  notes text null,
  created_at timestamptz not null default now(),
  primary key (source, raw_category)
);

-- Backfill normalized/norm_kind mutual compatibility where possible
-- (No-op if columns already populated or rows absent)
update public.hazard_type_map m
set norm_kind = coalesce(norm_kind, normalized),
    norm_severity = coalesce(norm_severity, nullif(severity,0))
where (norm_kind is null or norm_severity is null);

-- 1.2 Hazards base table additions (existing table kept; add missing cols/indexes)
-- Ensure columns ext_id and created_at exist
alter table if exists public.hazards
  add column if not exists ext_id text,
  add column if not exists created_at timestamptz not null default now();

-- Helpful indexes (idempotent)
create index if not exists idx_hazards_center on public.hazards using gist (center);
create index if not exists idx_hazards_observed_at on public.hazards (observed_at desc);
create index if not exists idx_hazards_geom on public.hazards using gist (geom);

-- Dedup unique index using coalesce(starts_at, observed_at)
create unique index if not exists hazards_src_ext_start_or_obs_uniq
  on public.hazards (source, ext_id, coalesce(starts_at, observed_at));

-- 1.3 Recent view (48h) — keep existing v_hazards_recent if present; re-create compatible superset
-- This definition preserves existing columns while staying close to spec
create or replace view public.v_hazards_recent as
select
  h.id,
  h.source,
  -- prefer richer normalization if present
  coalesce(m.norm_kind, m.normalized, h.kind) as kind,
  coalesce(m.norm_severity,
           case when h.severity ~ '^[0-9]+$' then (h.severity::int) end,
           case lower(h.severity)
             when 'minor' then 1
             when 'moderate' then 2
             when 'major' then 3
             when 'extreme' then 4
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
  on m.source = h.source
 and m.raw_category = coalesce(h.kind, (h.metadata->>'category'))
where (coalesce(h.ends_at, h.observed_at) >= now() - interval '48 hours');

-- 2) RLS and grants (reads to clients; writes via RPCs/Service)
alter table public.hazards enable row level security;
drop policy if exists hazards_read_all on public.hazards;
create policy hazards_read_all on public.hazards for select to authenticated, anon using (true);

grant select on public.hazards, public.v_hazards_recent to authenticated, anon;

-- 3) Seed richer incident_type_map (DOT + NOAA categories)
insert into public.hazard_type_map(source, raw_category, norm_kind, norm_severity, notes)
values
  ('dot', 'ACCIDENT', 'incident', 3, 'Traffic accident'),
  ('dot', 'INCIDENT', 'incident', 2, 'General incident'),
  ('dot', 'ROAD_CLOSED', 'closure', 4, 'Road closed'),
  ('dot', 'LANE_CLOSED', 'closure', 2, 'Lane closed'),
  ('dot', 'CONSTRUCTION', 'construction', 2, 'Work zone'),
  ('dot', 'CONGESTION', 'traffic', 1, 'Heavy traffic'),
  ('dot', 'WEATHER', 'weather', 2, 'Weather-related impact')
on conflict (source, raw_category) do nothing;

insert into public.hazard_type_map(source, raw_category, norm_kind, norm_severity, notes)
values
  ('noaa', 'TORNADO_WARNING', 'weather', 5, 'Tornado warning'),
  ('noaa', 'SEVERE_THUNDERSTORM_WARNING', 'weather', 4, 'Severe thunderstorm'),
  ('noaa', 'FLASH_FLOOD_WARNING', 'flood', 4, 'Flash flood'),
  ('noaa', 'WINTER_STORM_WARNING', 'ice', 3, 'Winter storm'),
  ('noaa', 'HIGH_WIND_WARNING', 'wind', 3, 'High wind'),
  ('noaa', 'DENSE_FOG_ADVISORY', 'fog', 2, 'Dense fog'),
  ('noaa', 'RED_FLAG_WARNING', 'fire', 3, 'Fire weather')
on conflict (source, raw_category) do nothing;

-- 4) RPCs

-- 4.1 Upsert GeoJSON Feature (server-only). Keeps existing array RPC intact.
create or replace function public.hazards_upsert_geojson_single(feat jsonb)
returns uuid
language plpgsql
security definer
as $$
declare
  j_geom jsonb;
  j_props jsonb;
  g geometry;
  src text;
  ext text;
  raw_cat text;
  norm_kind text;
  norm_sev smallint;
  obs timestamptz;
  s_at timestamptz;
  e_at timestamptz;
  id_out uuid;
begin
  if feat->>'type' <> 'Feature' then
    raise exception 'Invalid GeoJSON: expected Feature';
  end if;

  j_geom := feat->'geometry';
  if j_geom is null then
    raise exception 'Missing geometry';
  end if;

  g := st_setsrid(st_geomfromgeojson(j_geom::text), 4326);
  if st_srid(g) <> 4326 then
    raise exception 'Invalid SRID %, expected 4326', st_srid(g);
  end if;
  if st_isempty(g) then
    raise exception 'Empty geometry';
  end if;

  j_props := coalesce(feat->'properties','{}'::jsonb);
  src := coalesce(j_props->>'source','unknown');
  ext := coalesce(j_props->>'ext_id', gen_random_uuid()::text);
  raw_cat := coalesce(j_props->>'category', j_props->>'kind', 'UNKNOWN');
  obs := coalesce((j_props->>'observed_at')::timestamptz, now());
  s_at := (j_props->>'starts_at')::timestamptz;
  e_at := (j_props->>'ends_at')::timestamptz;

  select m.norm_kind, m.norm_severity into norm_kind, norm_sev
  from public.hazard_type_map m
  where m.source = src and m.raw_category = raw_cat;

  if norm_kind is null then
    norm_kind := coalesce(j_props->>'kind', 'other');
    norm_sev := coalesce(nullif(j_props->>'severity','')::smallint, 1);
  end if;

  insert into public.hazards as h
    (source, ext_id, kind, severity, observed_at, starts_at, ends_at, geom, metadata)
  values
    (src, ext, norm_kind, norm_sev::text, obs, s_at, e_at, st_simplifypreservetopology(g, 0.0005), j_props)
  on conflict (id)
  do update set
    kind = excluded.kind,
    severity = excluded.severity,
    observed_at = excluded.observed_at,
    starts_at = excluded.starts_at,
    ends_at = excluded.ends_at,
    geom = excluded.geom,
    metadata = excluded.metadata
  returning id into id_out;

  return id_out;
end $$;

revoke all on function public.hazards_upsert_geojson_single(jsonb) from public, anon, authenticated;
grant execute on function public.hazards_upsert_geojson_single(jsonb) to service_role;

-- 4.2 BBox query (full rows) with optional max_rows cap
create or replace function public.hazards_in_bbox_env(env geometry, max_rows int default 500)
returns setof public.hazards
language sql
security definer
as $$
  select *
  from public.hazards
  where st_srid(env) = 4326
    and geom && env
    and st_intersects(geom, env)
  order by observed_at desc
  limit greatest(0, least(coalesce(max_rows, 500), 5000))
$$;

revoke all on function public.hazards_in_bbox_env(geometry,int) from public;
grant execute on function public.hazards_in_bbox_env(geometry,int) to authenticated, anon, service_role;

-- 5) Retention & maintenance
-- Keep existing prune_hazards(...) (void) and add a variant returning deleted count
create or replace function public.prune_hazards_count(days_to_keep int)
returns int
language plpgsql
security definer
as $$
declare c int; begin
  with del as (
    delete from public.hazards
    where coalesce(ends_at, observed_at) < now() - make_interval(days => days_to_keep)
    returning 1
  ) select count(*) into c from del;
  return coalesce(c,0);
end $$;

revoke all on function public.prune_hazards_count(int) from public;
grant execute on function public.prune_hazards_count(int) to service_role;

-- 6) Partitioning (monthly by observed_at) — only if not already partitioned
-- Convert to partitioned if supported and not already; ignore if fails
do $$
begin
  if not exists (
    select 1 from pg_partitioned_table p
    join pg_class c on p.partrelid = c.oid
    where c.relname = 'hazards'
  ) then
    begin
      execute 'alter table public.hazards partition by range (observed_at)';
    exception when others then
      -- leave unpartitioned if conversion not supported in current PG
      null;
    end;
  end if;
end $$;

-- Create current and next month partitions if table is partitioned
do $$
declare
  is_part bool;
  start_curr date := date_trunc('month', now())::date;
  start_next date := (date_trunc('month', now()) + interval '1 month')::date;
  part_curr text := format('hazards_%s', to_char(start_curr, 'YYYYMM'));
  part_next text := format('hazards_%s', to_char(start_next, 'YYYYMM'));
begin
  select exists (
    select 1 from pg_partitioned_table p
    join pg_class c on p.partrelid = c.oid
    where c.relname = 'hazards'
  ) into is_part;

  if is_part then
    execute format($f$
      create table if not exists public.%I
      partition of public.hazards
      for values from (%L) to (%L)
    $f$, part_curr, start_curr, start_next);

    execute format($f$
      create table if not exists public.%I
      partition of public.hazards
      for values from (%L) to (%L)
    $f$, part_next, start_next, (start_next + interval '1 month')::date);

    -- indexes on partitions
    execute format('create index if not exists idx_%I_observed_at on public.%I (observed_at desc)', part_curr, part_curr);
    execute format('create index if not exists idx_%I_geom on public.%I using gist (geom)', part_curr, part_curr);
    execute format('create index if not exists idx_%I_center on public.%I using gist (center)', part_curr, part_curr);

    execute format('create index if not exists idx_%I_observed_at on public.%I (observed_at desc)', part_next, part_next);
    execute format('create index if not exists idx_%I_geom on public.%I using gist (geom)', part_next, part_next);
    execute format('create index if not exists idx_%I_center on public.%I using gist (center)', part_next, part_next);
  end if;
end $$;

-- 7) Helper view for unknown categories (normalization gap)
create or replace view public.v_hazards_unknown_categories as
select
  h.source,
  (h.metadata->>'category') as raw_category,
  count(*) as c
from public.hazards h
left join public.hazard_type_map m
  on m.source = h.source and m.raw_category = (h.metadata->>'category')
where (h.metadata->>'category') is not null
  and m.source is null
group by 1,2
order by c desc
limit 100;

grant select on public.v_hazards_unknown_categories to authenticated, anon;

-- 8) Sanity check RPCs (signatures visible)
-- \df+ public.hazards_upsert_geojson_single
-- \df+ public.hazards_in_bbox_env

-- Done.
