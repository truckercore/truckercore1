-- Migration: profile learning tables, policies, RPC
-- Date: 2025-09-27

-- Helpers: current_org_id() and current_app_role()
-- These are safe for RLS (LANGUAGE SQL, STABLE) and read from request headers first, then JWT claims.
create or replace function public.current_org_id() returns uuid
language sql stable as $$
  select coalesce(
    nullif((current_setting('request.headers', true)::jsonb ->> 'x-app-org-id'), '')::uuid,
    nullif((auth.jwt() ->> 'org_id'), '')::uuid
  );
$$;

grant execute on function public.current_org_id() to authenticated, anon;

create or replace function public.current_app_role() returns text
language sql stable as $$
  with hdr as (
    select coalesce((current_setting('request.headers', true)::jsonb ->> 'x-app-roles'), '') as roles
  )
  select nullif(lower(
    case
      when roles is not null and roles <> '' then split_part(roles, ',', 1)
      else coalesce(auth.jwt() ->> 'app_role', auth.jwt() ->> 'role')
    end
  ), '');
$$;

grant execute on function public.current_app_role() to authenticated, anon;

-- Tables
create table if not exists public.user_preferences (
  user_id uuid not null,
  org_id uuid not null,
  key text not null,
  value_json jsonb not null default '{}'::jsonb,
  source text not null default 'explicit',
  confidence numeric,
  updated_at timestamptz not null default now(),
  inserted_at timestamptz not null default now(),
  constraint user_preferences_pk primary key (user_id, org_id, key)
);

alter table public.user_preferences enable row level security;

create table if not exists public.behavior_events (
  id uuid not null default gen_random_uuid(),
  user_id uuid not null,
  org_id uuid not null,
  event_type text not null,
  properties jsonb not null default '{}'::jsonb,
  occurred_at timestamptz not null default now(),
  created_at timestamptz not null default now(),
  constraint behavior_events_pkey primary key (id)
);

create index if not exists idx_behavior_events_org_time on public.behavior_events(org_id, occurred_at desc);
create index if not exists idx_behavior_events_user_time on public.behavior_events(user_id, occurred_at desc);

alter table public.behavior_events enable row level security;

create table if not exists public.learned_profiles (
  user_id uuid not null,
  org_id uuid not null,
  features_json jsonb not null default '{}'::jsonb,
  confidence numeric,
  updated_at timestamptz not null default now(),
  inserted_at timestamptz not null default now(),
  constraint learned_profiles_user_org_uniq unique (user_id, org_id)
);

alter table public.learned_profiles enable row level security;

-- RLS policies (require current_org_id() and current_app_role() helpers)
create policy if not exists upsert_own_prefs on public.user_preferences
for all using (
  auth.uid() = user_id and public.current_org_id() = org_id
) with check (
  auth.uid() = user_id and public.current_org_id() = org_id
);

create policy if not exists insert_own_events on public.behavior_events
for insert to authenticated with check (
  auth.uid() = user_id and public.current_org_id() = org_id
);

create policy if not exists select_events_by_org on public.behavior_events
for select using (
  (auth.uid() = user_id and public.current_org_id() = org_id)
  or (public.current_app_role() in ('admin','manager') and public.current_org_id() = org_id)
);

create policy if not exists select_learned_profiles on public.learned_profiles
for select using (
  (auth.uid() = user_id and public.current_org_id() = org_id)
  or (public.current_app_role() in ('admin','manager') and public.current_org_id() = org_id)
);

-- RPC for service writes
create or replace function public.upsert_learned_profile(
  p_user_id uuid,
  p_org_id uuid,
  p_features jsonb,
  p_confidence numeric
) returns void
language plpgsql security definer set search_path = public as $$
begin
  insert into public.learned_profiles as lp (user_id, org_id, features_json, confidence, updated_at)
  values (p_user_id, p_org_id, coalesce(p_features, '{}'::jsonb), p_confidence, now())
  on conflict (user_id, org_id) do update
    set features_json = excluded.features_json,
        confidence = excluded.confidence,
        updated_at = now();

  -- Mirror selected features into user_preferences as 'learned'
  perform 1 from public.user_preferences;

  with to_mirror as (
    select key, value
    from jsonb_each(coalesce(p_features, '{}'::jsonb))
    where key in ('max_deadhead_miles','toll_aversion','pickup_window_local','preferred_corridors')
  )
  insert into public.user_preferences as up (user_id, org_id, key, value_json, source, confidence, updated_at)
  select p_user_id, p_org_id, key, to_jsonb(value), 'learned', p_confidence, now() from to_mirror
  on conflict (user_id, org_id, key) do update
    set value_json = excluded.value_json,
        source = 'learned',
        confidence = excluded.confidence,
        updated_at = now();
end; $$;

grant execute on function public.upsert_learned_profile(uuid, uuid, jsonb, numeric) to service_role;

-- Optional view
create or replace view public.merged_profile as
select
  lp.user_id,
  lp.org_id,
  coalesce(
    jsonb_strip_nulls(lp.features_json) ||
    (
      select jsonb_object_agg(key, value_json)
      from public.user_preferences up
      where up.user_id = lp.user_id
        and up.org_id = lp.org_id
        and up.source = 'explicit'
    ),
    '{}'::jsonb
  ) as features_json,
  lp.updated_at
from public.learned_profiles lp;
