-- Truck restrictions table and indexes
-- Run in your Supabase SQL editor or as a migration.

create table if not exists public.truck_restrictions (
  id bigserial primary key,
  state_code text not null,
  category text not null check (category in ('low_clearance','weigh_station','restricted_route')),
  description text not null,
  -- Flexible location storage. If PostGIS is enabled, prefer geom.
  location jsonb,               -- { "lat": number, "lng": number }
  geom geometry(Point, 4326),   -- optional
  source text default 'manual_v1',
  created_at timestamptz default now()
);

-- Idempotency on (state_code, category, description)
create unique index if not exists idx_tr_unique
  on public.truck_restrictions (state_code, category, description);

-- Indexes for filtering
create index if not exists idx_tr_state on public.truck_restrictions (state_code);
create index if not exists idx_tr_category on public.truck_restrictions (category);

-- If PostGIS is enabled, spatial index
do $$ begin
  if exists (select 1 from pg_extension where extname = 'postgis') then
    execute 'create index if not exists idx_tr_geom on public.truck_restrictions using gist (geom)';
  end if;
end $$;