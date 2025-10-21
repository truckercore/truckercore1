-- docs/supabase/sso_observability.sql
-- Observability schema for SSO/SCIM event tracking and error-rate views. Idempotent.

create extension if not exists pgcrypto;

-- raw SSO events (service role inserts)
create table if not exists public.sso_events (
  id bigserial primary key,
  org_id uuid not null,
  outcome text not null check (outcome in ('success','error')),
  error_code text null,
  message text null,
  ts timestamptz not null default now()
);
create index if not exists idx_sso_events_ts on public.sso_events(ts desc);
create index if not exists idx_sso_events_org_ts on public.sso_events(org_id, ts desc);

-- raw SCIM events
create table if not exists public.scim_events (
  id bigserial primary key,
  org_id uuid not null,
  op text not null check (op in ('Users.GET','Users.POST','Users.PATCH','Groups.GET','Groups.POST','Groups.PATCH')),
  outcome text not null check (outcome in ('success','error')),
  error_code text null,
  message text null,
  ts timestamptz not null default now()
);
create index if not exists idx_scim_events_ts on public.scim_events(ts desc);
create index if not exists idx_scim_events_org_ts on public.scim_events(org_id, ts desc);

-- RLS: read for authenticated (own org) if you want to surface in UI; writes via service role only.
alter table public.sso_events enable row level security;
alter table public.scim_events enable row level security;

create or replace function public.jwt_claim(claim text)
returns text stable language sql as $$ select coalesce(current_setting('request.jwt.claims', true)::json->>claim, '') $$;

DO $$ BEGIN
  DROP POLICY IF EXISTS sso_events_read ON public.sso_events;
  CREATE POLICY sso_events_read ON public.sso_events FOR SELECT TO authenticated USING (
    org_id::text = public.jwt_claim('app_org_id')
  );
END $$;
DO $$ BEGIN
  DROP POLICY IF EXISTS scim_events_read ON public.scim_events;
  CREATE POLICY scim_events_read ON public.scim_events FOR SELECT TO authenticated USING (
    org_id::text = public.jwt_claim('app_org_id')
  );
END $$;

-- 15-minute error-rate views
create or replace view public.v_sso_error_rate_15m as
select org_id,
       count(*) filter (where outcome='error')::numeric / nullif(count(*),0) as error_rate,
       min(ts) as window_start,
       max(ts) as window_end
from public.sso_events
where ts >= now() - interval '15 minutes'
group by org_id;

create or replace view public.v_scim_failures_15m as
select org_id,
       count(*) filter (where outcome='error') as failures,
       min(ts) as window_start,
       max(ts) as window_end
from public.scim_events
where ts >= now() - interval '15 minutes'
group by org_id;
