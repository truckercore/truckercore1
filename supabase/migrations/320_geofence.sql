-- Geofence polygons
create table if not exists public.geofences (
  id uuid primary key default gen_random_uuid(),
  org_id uuid not null references public.orgs(id),
  name text not null,
  geom geometry(Polygon, 4326) not null,
  created_at timestamptz not null default now()
);
create index if not exists idx_geofences_gix on public.geofences using gist(geom);
alter table public.geofences enable row level security;
create policy geofences_org_rw on public.geofences
for all to authenticated
using (org_id::text = coalesce(current_setting('request.jwt.claims', true)::json->>'app_org_id',''))
with check (org_id::text = coalesce(current_setting('request.jwt.claims', true)::json->>'app_org_id',''));
