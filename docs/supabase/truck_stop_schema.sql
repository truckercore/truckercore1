-- docs/supabase/truck_stop_schema.sql
-- Truck Stop Operator + Driver schema (MVP)
-- Apply in Supabase SQL editor or via CLI psql.

-- Enums
create type role_enum as enum ('corp_admin','regional_manager','location_manager');
create type parking_status_enum as enum ('open','limited','full','unknown');
create type source_enum as enum ('operator','iot','crowd','corporate','local');
create type promo_status_enum as enum ('draft','active','expired');
create type detour_tolerance_enum as enum ('strict','normal','flex');

-- Orgs
create table if not exists orgs (
  org_id uuid primary key default gen_random_uuid(),
  name text not null,
  slug text unique,
  created_at timestamptz not null default now()
);

-- Locations
create table if not exists locations (
  location_id uuid primary key default gen_random_uuid(),
  org_id uuid not null references orgs(org_id) on delete cascade,
  name text not null,
  address text,
  lat double precision not null,
  lng double precision not null,
  store_id text,
  region text,
  timezone text,
  created_at timestamptz not null default now()
);
create index if not exists idx_locations_org on locations(org_id);
create index if not exists idx_locations_geo on locations using gist (ll_to_earth(lat, lng));

-- Users table is auth.users; shadow table for org mapping (optional if profiles exists)
create table if not exists users (
  user_id uuid primary key,
  email text,
  org_id uuid references orgs(org_id) on delete set null,
  created_at timestamptz not null default now()
);

-- Roles
create table if not exists user_roles (
  user_id uuid not null references users(user_id) on delete cascade,
  org_id uuid not null references orgs(org_id) on delete cascade,
  role role_enum not null,
  primary key (user_id, org_id, role)
);

-- Explicit access to locations
create table if not exists location_access (
  user_id uuid not null references users(user_id) on delete cascade,
  location_id uuid not null references locations(location_id) on delete cascade,
  primary key (user_id, location_id)
);
create index if not exists idx_location_access_user on location_access(user_id);

-- Parking status reports (raw)
create table if not exists parking_status (
  id bigserial primary key,
  location_id uuid not null references locations(location_id) on delete cascade,
  source source_enum not null default 'operator',
  available_spots int,
  capacity int,
  status parking_status_enum not null default 'unknown',
  confidence numeric,
  updated_by uuid,
  updated_at timestamptz not null default now()
);
create index if not exists idx_parking_status_loc_time on parking_status(location_id, updated_at desc);

-- Fuel prices
create table if not exists fuel_prices (
  id bigserial primary key,
  location_id uuid not null references locations(location_id) on delete cascade,
  diesel_cents int not null,
  discount_cents int default 0,
  effective_at timestamptz not null default now(),
  source source_enum not null default 'local'
);
create index if not exists idx_fuel_prices_loc_time on fuel_prices(location_id, effective_at desc);

-- Promotions
create table if not exists promotions (
  id bigserial primary key,
  org_id uuid not null references orgs(org_id) on delete cascade,
  location_id uuid references locations(location_id) on delete cascade,
  title text not null,
  body text,
  media_url text,
  starts_at timestamptz not null,
  ends_at timestamptz not null,
  status promo_status_enum not null default 'draft',
  targeting jsonb
);
create index if not exists idx_promotions_org_time on promotions(org_id, starts_at, ends_at);
create index if not exists idx_promotions_loc_time on promotions(location_id, starts_at, ends_at);

-- Reviews
create table if not exists reviews (
  id bigserial primary key,
  location_id uuid not null references locations(location_id) on delete cascade,
  user_id uuid,
  rating int check (rating between 1 and 5),
  text text,
  created_at timestamptz not null default now()
);
create index if not exists idx_reviews_loc_time on reviews(location_id, created_at desc);

-- Confidence snapshot
create table if not exists stop_confidence (
  location_id uuid primary key references locations(location_id) on delete cascade,
  metric text not null default 'parking',
  confidence numeric not null,
  last_update timestamptz not null
);

-- Scores
create table if not exists stop_scores (
  location_id uuid primary key references locations(location_id) on delete cascade,
  score numeric not null,
  factors jsonb not null,
  updated_at timestamptz not null default now()
);

-- User preferences
create table if not exists user_preferences (
  user_id uuid primary key,
  loyalty_brands text[] default '{}',
  amenity_priority jsonb default '{}'::jsonb,
  detour_tolerance detour_tolerance_enum not null default 'normal',
  updated_at timestamptz not null default now()
);

-- Simple views for operator dashboard convenience
create or replace view v_location_latest as
select l.location_id,
       l.org_id,
       l.name,
       l.lat,
       l.lng,
       (select ps.status from parking_status ps where ps.location_id=l.location_id order by ps.updated_at desc limit 1) as parking_status,
       (select ps.available_spots from parking_status ps where ps.location_id=l.location_id order by ps.updated_at desc limit 1) as available_spots,
       (select fp.diesel_cents - coalesce(fp.discount_cents,0) from fuel_prices fp where fp.location_id=l.location_id order by fp.effective_at desc limit 1) as diesel_effective_cents,
       (select s.score from stop_scores s where s.location_id=l.location_id) as score
from locations l;

-- Notes:
-- 1) Apply RLS and policies via truck_stop_rls.sql
-- 2) Add optional *_audit tables later if needed.
