-- Phase 0 — Foundations: org/role enforcement helpers and event outbox

-- 1) Role helper: has_role(text) reads app_roles[] from JWT claims
create or replace function public.has_role(target_role text)
returns boolean
language sql
stable
as $$
  select coalesce(current_setting('request.jwt.claims', true)::json->'app_roles','[]'::json) ? target_role;
$$;

comment on function public.has_role(text) is 'Checks whether current JWT app_roles contains the provided role';

-- 2) Event outbox table for canonical events
create table if not exists public.event_outbox (
  id uuid primary key default gen_random_uuid(),
  org_id uuid not null,
  event_key text generated always as (concat(event_type, ':', coalesce(dedup_key,''))) stored,
  event_type text not null, -- e.g., location.updated, load.assigned, document.uploaded, doc.validated, alert.triggered
  schema_version int not null default 1,
  payload jsonb not null,
  dedup_key text null, -- caller-supplied for idempotency (unique per org+event type ideally)
  created_at timestamptz not null default now(),
  delivered_at timestamptz null,
  delivery_attempts int not null default 0,
  last_error text null
);

create index if not exists idx_outbox_org_time on public.event_outbox (org_id, created_at desc);
create index if not exists idx_outbox_event on public.event_outbox (event_type);
create index if not exists idx_outbox_dedup on public.event_outbox (org_id, event_type, dedup_key);

alter table public.event_outbox enable row level security;
-- Only service role can read/write by default; expose a limited insert via function below
create policy outbox_no_direct_access on public.event_outbox for all to authenticated using (false) with check (false);

-- 2.1) Enqueue function with idempotency on (org_id, event_type, dedup_key)
create or replace function public.enqueue_event(
  p_org_id uuid,
  p_event_type text,
  p_schema_version int,
  p_payload jsonb,
  p_dedup_key text default null
) returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_id uuid;
begin
  if p_dedup_key is not null then
    select id into v_id from public.event_outbox
      where org_id = p_org_id and event_type = p_event_type and dedup_key = p_dedup_key
      order by created_at desc limit 1;
    if v_id is not null then
      return v_id; -- idempotent
    end if;
  end if;

  insert into public.event_outbox(org_id, event_type, schema_version, payload, dedup_key)
  values (p_org_id, p_event_type, p_schema_version, p_payload, p_dedup_key)
  returning id into v_id;
  return v_id;
end;
$$;

revoke all on function public.enqueue_event(uuid, text, int, jsonb, text) from public;
grant execute on function public.enqueue_event(uuid, text, int, jsonb, text) to authenticated, service_role;

-- 3) Minimal webhook subscription + deliveries (MVP)
create table if not exists public.webhook_subscriptions (
  id uuid primary key default gen_random_uuid(),
  org_id uuid not null,
  url text not null,
  secret text not null,
  active boolean not null default true,
  created_at timestamptz not null default now()
);
create index if not exists idx_webhook_subs_org on public.webhook_subscriptions (org_id);
alter table public.webhook_subscriptions enable row level security;
create policy webhook_subs_service_only on public.webhook_subscriptions for all to authenticated using (false) with check (false);

create table if not exists public.webhook_deliveries (
  id uuid primary key default gen_random_uuid(),
  outbox_id uuid not null references public.event_outbox(id) on delete cascade,
  subscription_id uuid not null references public.webhook_subscriptions(id) on delete cascade,
  attempt int not null default 0,
  status text not null default 'pending', -- pending/success/failed
  response_code int null,
  error text null,
  next_attempt_at timestamptz null,
  created_at timestamptz not null default now()
);
create index if not exists idx_webhook_deliveries_outbox on public.webhook_deliveries (outbox_id);
alter table public.webhook_deliveries enable row level security;
create policy webhook_deliveries_service_only on public.webhook_deliveries for all to authenticated using (false) with check (false);

-- 4) Example trigger: emit alert.triggered when alerts_events row is inserted
create or replace function public.trg_alerts_events_outbox()
returns trigger
language plpgsql
as $$
begin
  perform public.enqueue_event(
    NEW.org_id,
    'alert.triggered',
    1,
    jsonb_build_object(
      'id', NEW.id,
      'severity', NEW.severity,
      'code', NEW.code,
      'payload', NEW.payload,
      'triggered_at', NEW.triggered_at
    ),
    NEW.id::text
  );
  return NEW;
end;
$$;

-- ensure the table exists (from later migrations) before creating trigger
do $$ begin
  if exists (select 1 from information_schema.tables where table_schema = 'public' and table_name = 'alerts_events') then
    drop trigger if exists alerts_events_outbox on public.alerts_events;
    create trigger alerts_events_outbox
      after insert on public.alerts_events
      for each row execute procedure public.trg_alerts_events_outbox();
  end if;
end $$;

-- 5) Tighten an existing policy with role requirement (example): inspection insert must be driver
do $$ begin
  if exists (select 1 from information_schema.tables where table_schema = 'public' and table_name = 'inspection_reports') then
    drop policy if exists inspection_insert_driver on public.inspection_reports;
    create policy inspection_insert_driver on public.inspection_reports for insert to authenticated
    with check (
      org_id::text = coalesce(current_setting('request.jwt.claims', true)::json->>'app_org_id','') and
      driver_user_id::text = coalesce(current_setting('request.jwt.claims', true)::json->>'sub','') and
      public.has_role('driver')
    );
  end if;
end $$;
