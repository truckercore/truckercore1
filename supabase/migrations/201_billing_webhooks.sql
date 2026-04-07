-- Central audit of billing webhooks
create table if not exists public.webhook_events (
  id uuid primary key default gen_random_uuid(),
  provider text not null,                 -- 'stripe'
  event_id text not null,                 -- provider id (unique)
  received_at timestamptz not null default now(),
  status text not null default 'received',-- received|processed|errored|duplicate
  org_id uuid null references public.orgs(id) on delete set null,
  event_type text not null,
  payload jsonb not null,
  error text
);

create unique index if not exists uq_webhook_events_provider_event
  on public.webhook_events(provider, event_id);

create index if not exists idx_webhook_events_org_ts
  on public.webhook_events(org_id, received_at desc);

-- Admin view: current license state + last event
create or replace view public.admin_org_license_overview as
select
  o.id as org_id,
  o.plan,
  o.license_status,
  o.app_is_premium,
  (select we.event_type from public.webhook_events we
     where we.org_id = o.id
     order by we.received_at desc limit 1) as last_event_type,
  (select we.received_at from public.webhook_events we
     where we.org_id = o.id
     order by we.received_at desc limit 1) as last_event_at
from public.orgs o;

-- Optional: daily CSV usage view (if csv_ingest_usage exists)
do $$
begin
  if exists (
    select 1 from information_schema.tables
    where table_schema = 'public' and table_name = 'csv_ingest_usage'
  ) then
    execute $v$
      create or replace view public.admin_csv_usage_daily as
      select
        org_id,
        date_trunc('day', occurred_at) as day,
        sum(bytes)::bigint as bytes,
        sum(files)::bigint as files
      from public.csv_ingest_usage
      group by 1,2;
    $v$;
  end if;
end$$;

-- RLS and policies
alter table public.webhook_events enable row level security;

-- Only service_role can write webhooks
drop policy if exists webhook_events_service_write on public.webhook_events;
create policy webhook_events_service_write
on public.webhook_events
for insert
to service_role
with check (true);

-- Admins can read (if user_roles exists). Otherwise keep service-only.
do $$
begin
  if exists (
    select 1 from information_schema.tables
    where table_schema = 'public' and table_name = 'user_roles'
  ) then
    drop policy if exists webhook_events_admin_read on public.webhook_events;
    create policy webhook_events_admin_read
    on public.webhook_events
    for select
    to authenticated
    using (
      exists (
        select 1 from public.user_roles ur
        where ur.user_id = auth.uid() and ur.role = 'admin'
      )
    );
  end if;
end$$;