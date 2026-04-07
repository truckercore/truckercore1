-- 200_licensing_core.sql
-- Licensing core: orgs, licenses, events, idempotency, CSV quotas

-- Ensure orgs table exists and contains required columns
create table if not exists public.orgs (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  stripe_customer_id text,
  plan text not null default 'free', -- free|premium|enterprise
  premium boolean not null default false,
  seats int not null default 1,
  csv_daily_bytes_used bigint not null default 0,
  csv_bytes_reset_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  created_at timestamptz not null default now()
);

-- Add/align columns if table already existed
alter table if exists public.orgs add column if not exists stripe_customer_id text;
alter table if exists public.orgs add column if not exists plan text not null default 'free';
alter table if exists public.orgs add column if not exists premium boolean not null default false;
alter table if exists public.orgs add column if not exists seats int not null default 1;
alter table if exists public.orgs add column if not exists csv_daily_bytes_used bigint not null default 0;
alter table if exists public.orgs add column if not exists csv_bytes_reset_at timestamptz not null default now();
alter table if exists public.orgs add column if not exists updated_at timestamptz not null default now();
alter table if exists public.orgs add column if not exists created_at timestamptz not null default now();

-- License event log
create table if not exists public.org_license_events (
  id bigserial primary key,
  org_id uuid not null references public.orgs(id) on delete cascade,
  event_type text not null, -- stripe_invoice_paid|plan_changed|seat_adjust|webhook_retry|refresh
  payload jsonb not null default '{}'::jsonb,
  idempotency_key text,
  created_at timestamptz not null default now()
);
create index if not exists org_license_events_org_idx on public.org_license_events(org_id);
create index if not exists org_license_events_idemp_idx on public.org_license_events(idempotency_key);

-- API idempotency (also used by webhook TTL cache)
create table if not exists public.api_idempotency_keys (
  key text primary key,
  expires_at timestamptz not null
);

-- CSV import audit for quota enforcement
create table if not exists public.csv_import_audit (
  id bigserial primary key,
  org_id uuid not null references public.orgs(id) on delete cascade,
  bytes bigint not null,
  file_name text,
  created_at timestamptz not null default now()
);
create index if not exists csv_import_audit_org_idx on public.csv_import_audit(org_id, created_at desc);

-- Utility function: reset CSV daily window when needed
create or replace function public.reset_csv_window_if_needed(p_org uuid)
returns void
language plpgsql
as $$
declare
  current_reset timestamptz;
begin
  select csv_bytes_reset_at into current_reset from public.orgs where id = p_org for update;
  if current_reset is null or current_reset < date_trunc('day', now()) then
    update public.orgs
    set csv_daily_bytes_used = 0,
        csv_bytes_reset_at = date_trunc('day', now()),
        updated_at = now()
    where id = p_org;
  end if;
end $$;

-- Function: add CSV usage (enforce limit externally in API)
create or replace function public.add_csv_usage(p_org uuid, p_bytes bigint)
returns void
language plpgsql
as $$
begin
  perform public.reset_csv_window_if_needed(p_org);
  update public.orgs
  set csv_daily_bytes_used = csv_daily_bytes_used + p_bytes,
      updated_at = now()
  where id = p_org;
end $$;

-- View: license status join (simple)
create or replace view public.v_org_license_status as
select
  id as org_id,
  plan,
  premium,
  seats,
  csv_daily_bytes_used,
  csv_bytes_reset_at
from public.orgs;

-- Grants for status view
alter view public.v_org_license_status owner to postgres;
grant select on public.v_org_license_status to anon, authenticated;
