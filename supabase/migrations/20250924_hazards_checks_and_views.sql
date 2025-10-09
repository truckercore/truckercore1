-- 20250924_hazards_checks_and_views.sql
-- Purpose: Monitoring add-ons, grants hardening, and UI-friendly enrichments for hazards.
-- Safe to re-run (idempotent where possible).

-- 1) Freshness tile per source
create or replace view public.hazards_freshness as
select source, now() - max(observed_at) as lag
from public.hazards
group by source;

-- 2) Ensure prune_hazards() is service-only (scheduler)
-- Note: function may or may not exist; use DO block to conditionally revoke/grant
do $$
begin
  if exists (
    select 1 from pg_proc p
    join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public' and p.proname = 'prune_hazards'
  ) then
    revoke all on function public.prune_hazards(int) from public, anon, authenticated;
    grant execute on function public.prune_hazards(int) to service_role;
  end if;
end $$;

-- 3) UI metadata enrichment: add updated_minutes_ago to recent view without breaking existing consumers
-- Preserve existing columns; append updated_minutes_ago
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
             when 'extreme' then 4
             else null
           end) as severity,
  h.title,
  h.description,
  h.starts_at,
  h.ends_at,
  h.observed_at,
  st_asgeojson(h.geom)::jsonb as geojson,
  h.metadata,
  floor(extract(epoch from (now() - h.observed_at))/60)::int as updated_minutes_ago
from public.hazards h
left join public.hazard_type_map m
  on m.source = h.source and m.raw_category = coalesce(h.kind, (h.metadata->>'category'))
where h.observed_at >= now() - interval '7 days';

-- Ensure grants as per guidance
grant select on public.v_hazards_recent to authenticated, anon;

-- 4) Confidence blending view (simple weighted + time decay example)
create or replace view public.v_hazards_confidence as
select
  h.id,
  h.source,
  h.geom,
  h.observed_at,
  coalesce(h.metadata->>'severity','unknown') as severity,
  (
    1.0 * case when h.source = 'dot' then 1 else 0 end +
    0.6 * case when h.source = 'partner' then 1 else 0 end +
    0.4 * case when h.source = 'crowd' then 1 else 0 end
  )::double precision
  * exp(-least(extract(epoch from (now()-h.observed_at))/3600.0, 48)/24.0) as confidence_score
from public.hazards h;

-- 5) Keep RPC grants aligned (no-op if already applied)
-- hazards_upsert_* should be service_role only; bbox/view readable to anon/auth
-- Re-assert grants safely
revoke all on function public.hazards_upsert_geojson(jsonb) from public, anon, authenticated;
grant execute on function public.hazards_upsert_geojson(jsonb) to service_role;

-- Optional alternate single-feature RPC (if present)
do $$
begin
  if exists (
    select 1 from pg_proc p
    join pg_namespace n on n.oid = p.pronamespace
    where n.nspname='public' and p.proname='hazards_upsert_geojson_single'
  ) then
    revoke all on function public.hazards_upsert_geojson_single(jsonb) from public, anon, authenticated;
    grant execute on function public.hazards_upsert_geojson_single(jsonb) to service_role;
  end if;
end $$;

-- bbox RPC grants
grant execute on function public.hazards_in_bbox(geometry,int) to anon, authenticated;
