-- ============================================================
-- MIGRATION: AI Alert Copilot System
-- ============================================================

-- 1. Create alert_events table
create table if not exists public.alert_events (
  id uuid primary key default gen_random_uuid(),
  org_id uuid not null references public.organizations(id) on delete cascade,
  driver_id uuid references public.profiles(id) on delete set null,
  vehicle_id uuid references public.vehicles(id) on delete set null,
  load_id uuid references public.loads(id) on delete set null,
  alert_type text not null,
  severity text not null check (severity in ('low', 'medium', 'high', 'critical')),
  status text not null default 'open' check (status in ('open', 'acknowledged', 'resolved', 'dismissed', 'snoozed')),
  title text not null,
  summary text not null,
  explanation text,
  recommended_action text,
  confidence numeric,
  source text not null default 'system',
  ai_generated boolean not null default false,
  assigned_to uuid references public.profiles(id) on delete set null,
  assignee_role text,
  auto_escalate boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  resolved_at timestamptz,
  metadata jsonb not null default '{}'::jsonb,
  dedup_hash text,
  dedup_bucket text
);

-- Index for fast queries
create index if not exists idx_alert_events_org_status on public.alert_events(org_id, status, created_at desc);
create index if not exists idx_alert_events_dedup on public.alert_events(dedup_hash) where dedup_hash is not null;

-- 2. Create alert_signal_events table (raw signals for rule engine)
create table if not exists public.alert_signal_events (
  id uuid primary key default gen_random_uuid(),
  org_id uuid not null references public.organizations(id) on delete cascade,
  driver_id uuid references public.profiles(id) on delete set null,
  vehicle_id uuid references public.vehicles(id) on delete set null,
  load_id uuid references public.loads(id) on delete set null,
  signal_type text not null,
  signal_value jsonb not null,
  created_at timestamptz not null default now(),
  processed boolean not null default false,
  processed_at timestamptz
);

create index if not exists idx_alert_signals_unprocessed on public.alert_signal_events(processed) where processed = false;

-- 3. Create alert_action_log table
create table if not exists public.alert_action_log (
  id uuid primary key default gen_random_uuid(),
  alert_id uuid not null references public.alert_events(id) on delete cascade,
  actor_id uuid references public.profiles(id) on delete set null,
  action_type text not null,
  note text,
  created_at timestamptz not null default now(),
  metadata jsonb not null default '{}'::jsonb
);

-- 4. Create alert_policies table
create table if not exists public.alert_policies (
  id uuid primary key default gen_random_uuid(),
  org_id uuid not null references public.organizations(id) on delete cascade,
  policy_key text not null,
  policy_value jsonb not null,
  updated_at timestamptz not null default now(),
  unique(org_id, policy_key)
);

-- 5. Create alert_notification_queue table
create table if not exists public.alert_notification_queue (
  id uuid primary key default gen_random_uuid(),
  alert_id uuid not null references public.alert_events(id) on delete cascade,
  recipient_user_id uuid not null references public.profiles(id) on delete cascade,
  channel text not null check (channel in ('in_app', 'push', 'sms', 'email', 'webhook')),
  delivery_status text not null default 'pending' check (delivery_status in ('pending', 'sent', 'failed', 'skipped')),
  retry_count int not null default 0,
  scheduled_for timestamptz not null default now(),
  sent_at timestamptz,
  last_error text
);

-- RLS Policies
alter table public.alert_events enable row level security;
alter table public.alert_signal_events enable row level security;
alter table public.alert_action_log enable row level security;
alter table public.alert_policies enable row level security;
alter table public.alert_notification_queue enable row level security;

-- Simple RLS: members of the same org can read/write (adjust as needed)
create policy "org_access_alert_events" on public.alert_events
  for all using (org_id in (select org_id from public.organization_members where user_id = auth.uid()));

create policy "org_access_alert_signals" on public.alert_signal_events
  for all using (org_id in (select org_id from public.organization_members where user_id = auth.uid()));

create policy "org_access_alert_actions" on public.alert_action_log
  for all using (alert_id in (select id from public.alert_events where org_id in (select org_id from public.organization_members where user_id = auth.uid())));

create policy "org_access_alert_policies" on public.alert_policies
  for all using (org_id in (select org_id from public.organization_members where user_id = auth.uid()));

create policy "org_access_notification_queue" on public.alert_notification_queue
  for all using (alert_id in (select id from public.alert_events where org_id in (select org_id from public.organization_members where user_id = auth.uid())));
