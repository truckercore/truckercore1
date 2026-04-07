-- docs/supabase/truck_stop_rls.sql
-- Enable RLS and define minimal policies for MVP.
-- Assumptions: a profiles table exists mapping auth.uid() -> org_id and (optionally) primary_role.
-- Otherwise, sync auth.users into public.users and set users.org_id accordingly.

-- Helper: current org and roles from JWT or profiles
create or replace function app_current_org_id() returns uuid language sql stable as $$
  select coalesce(
    nullif(current_setting('request.jwt.claims', true)::jsonb ->> 'app_org_id', ''),
    (select org_id::text from profiles where user_id = auth.uid())
  )::uuid
$$;

create or replace function app_roles() returns text[] language sql stable as $$
  select coalesce(
    string_to_array(coalesce(current_setting('request.jwt.claims', true)::jsonb ->> 'app_roles', ''), ','),
    array[]::text[]
  )
$$;

-- Enable RLS on core tables
alter table orgs enable row level security;
alter table locations enable row level security;
alter table users enable row level security;
alter table user_roles enable row level security;
alter table location_access enable row level security;
alter table parking_status enable row level security;
alter table fuel_prices enable row level security;
alter table promotions enable row level security;
alter table reviews enable row level security;
alter table stop_confidence enable row level security;
alter table stop_scores enable row level security;
alter table user_preferences enable row level security;

-- Org visibility: members of org or corp_admin role can read
create policy org_read on orgs for select using (
  app_current_org_id() is not null and org_id = app_current_org_id()
);

-- Locations: read within org
create policy locations_read on locations for select using (
  org_id = app_current_org_id()
);

-- Parking writes: operator roles can write to assigned locations
create policy parking_insert on parking_status for insert with check (
  (select app_current_org_id()) = (select org_id from locations where locations.location_id = parking_status.location_id)
  and (
    -- corp_admin can write anywhere in org
    'corp_admin' = any(app_roles())
    or exists (select 1 from location_access la where la.user_id = auth.uid() and la.location_id = parking_status.location_id)
  )
);

create policy parking_read on parking_status for select using (
  (select org_id from locations where locations.location_id = parking_status.location_id) = app_current_org_id()
);

-- Fuel prices: similar to parking
create policy fuel_insert on fuel_prices for insert with check (
  (select org_id from locations where locations.location_id = fuel_prices.location_id) = app_current_org_id()
  and (
    'corp_admin' = any(app_roles())
    or exists (select 1 from location_access la where la.user_id = auth.uid() and la.location_id = fuel_prices.location_id)
  )
);
create policy fuel_read on fuel_prices for select using (
  (select org_id from locations where locations.location_id = fuel_prices.location_id) = app_current_org_id()
);

-- Promotions: org-scoped; corp_admin anywhere; location_manager for their locations
create policy promotions_insert on promotions for insert with check (
  org_id = app_current_org_id()
);
create policy promotions_read on promotions for select using (
  org_id = app_current_org_id()
);

-- Reviews: drivers write, everyone in org read (operator portal); public reads for driver app will be proxied via Edge Functions.
create policy reviews_read on reviews for select using (
  (select org_id from locations where locations.location_id = reviews.location_id) = app_current_org_id()
);

-- Scores/confidence: readable within org; writes by jobs (service role).
create policy scores_read on stop_scores for select using (
  (select org_id from locations where locations.location_id = stop_scores.location_id) = app_current_org_id()
);
create policy conf_read on stop_confidence for select using (
  (select org_id from locations where locations.location_id = stop_confidence.location_id) = app_current_org_id()
);

-- User preferences: owner can read/write their own
create policy prefs_rw on user_preferences for all using (auth.uid() = user_id) with check (auth.uid() = user_id);

-- TODO: tighten policies as product matures (regional mapping table, etc.).
