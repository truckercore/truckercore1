begin;

-- Enable PostGIS if present; safe if already installed (comment out if not using PostGIS)
-- create extension if not exists postgis;

-- Minimal POIs for parking & weigh
create table if not exists pois (
  id uuid primary key default gen_random_uuid(),
  kind text not null check (kind in ('parking','weigh')),
  name text not null,
  geom geometry(Point, 4326) not null,
  created_at timestamptz default now()
);
create index if not exists idx_pois_geom on pois using gist (geom);

-- Aggregated state (publicly readable)
create table if not exists poi_state (
  poi_id uuid primary key references pois(id) on delete cascade,
  state jsonb not null default '{}'::jsonb,    -- e.g. {"occupancy":"open","spaces_free":42}
  confidence numeric not null default 0.0 check (confidence >= 0 and confidence <= 1),
  updated_at timestamptz default now()
);

alter table poi_state enable row level security;
do $$
begin
  if not exists (
    select 1 from pg_policies
    where schemaname='public' and tablename='poi_state' and policyname='poi_state_public_read'
  ) then
    create policy poi_state_public_read on poi_state for select using (true);
  end if;
end $$;

-- Optional decay view for inspections
create or replace view poi_state_decay as
select poi_id, state, confidence,
       greatest(0.0, confidence - extract(epoch from (now()-updated_at))/3600.0*0.1) as decayed_confidence,
       updated_at
from poi_state;

comment on table pois is 'Points of interest for parking and weigh stations';
comment on table poi_state is 'Aggregated public state of POIs (parking/weigh)';

commit;
