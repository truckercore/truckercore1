-- 05_week1_foundations.sql
-- Week 1 — Foundations: Outbox/Webhooks/API Keys/Idempotency + Saved Searches/Alerts + Privacy Logs
-- Tables created with org_id and RLS baseline. JWT must include org_id claim (request.jwt.claims->>'org_id').

-- 1) Outbox events (for webhook delivery workers)
create table if not exists public.outbox_events (
  id bigserial primary key,
  org_id uuid not null,
  topic text not null,
  version text not null default '1',
  aggregate_type text,
  aggregate_id text,
  key text, -- optional idempotency/ordering key per aggregate
  payload jsonb not null,
  status text not null default 'pending', -- pending|delivered|dead
  attempts integer not null default 0,
  next_attempt_at timestamptz,
  lease_until timestamptz,
  last_status_code integer,
  last_error text,
  delivered_at timestamptz,
  created_at timestamptz not null default now()
);
create index if not exists idx_outbox_org_created on public.outbox_events(org_id, created_at desc);
create index if not exists idx_outbox_status_next on public.outbox_events(status, next_attempt_at);
create index if not exists idx_outbox_lease on public.outbox_events(lease_until) where status = 'pending';

alter table public.outbox_events enable row level security;
revoke all on table public.outbox_events from public;
-- Service role full access; org users read own events (optional)
create policy if not exists outbox_select_org on public.outbox_events
  for select using (
    auth.role() = 'service_role' or (
      (current_setting('request.jwt.claims', true)::jsonb ->> 'org_id')::uuid = org_id
    )
  );
create policy if not exists outbox_insert_service on public.outbox_events
  for insert with check (auth.role() = 'service_role');
create policy if not exists outbox_update_service on public.outbox_events
  for update using (auth.role() = 'service_role') with check (auth.role() = 'service_role');

-- 2) Webhook subscriptions (org-scoped)
create table if not exists public.webhook_subscriptions (
  id uuid primary key default gen_random_uuid(),
  org_id uuid not null,
  name text not null,
  endpoint_url text not null,
  secret_hash text not null, -- store hash only
  topics jsonb not null default '[]'::jsonb,
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create index if not exists idx_webhooks_org on public.webhook_subscriptions(org_id);

alter table public.webhook_subscriptions enable row level security;
revoke all on table public.webhook_subscriptions from public;
create policy if not exists webhooks_select_org on public.webhook_subscriptions
  for select using ((current_setting('request.jwt.claims', true)::jsonb ->> 'org_id')::uuid = org_id or auth.role() = 'service_role');
create policy if not exists webhooks_modify_org on public.webhook_subscriptions
  for all using ((current_setting('request.jwt.claims', true)::jsonb ->> 'org_id')::uuid = org_id or auth.role() = 'service_role')
  with check ((current_setting('request.jwt.claims', true)::jsonb ->> 'org_id')::uuid = org_id or auth.role() = 'service_role');

-- 3) API keys (hashed storage)
create table if not exists public.api_keys (
  id uuid primary key default gen_random_uuid(),
  org_id uuid not null,
  name text not null,
  key_hash text not null,
  scopes text[] not null default '{}',
  created_at timestamptz not null default now(),
  last_used_at timestamptz
);
create index if not exists idx_api_keys_org on public.api_keys(org_id);
create index if not exists idx_api_keys_org_name on public.api_keys(org_id, name);

alter table public.api_keys enable row level security;
revoke all on table public.api_keys from public;
create policy if not exists api_keys_select_org on public.api_keys
  for select using ((current_setting('request.jwt.claims', true)::jsonb ->> 'org_id')::uuid = org_id or auth.role() = 'service_role');
create policy if not exists api_keys_modify_org on public.api_keys
  for all using ((current_setting('request.jwt.claims', true)::jsonb ->> 'org_id')::uuid = org_id or auth.role() = 'service_role')
  with check ((current_setting('request.jwt.claims', true)::jsonb ->> 'org_id')::uuid = org_id or auth.role() = 'service_role');

-- 4) General idempotency store (separate from org_idempotency_keys used by RPC example)
create table if not exists public.api_idempotency_keys (
  key text primary key,
  org_id uuid not null,
  endpoint text not null,
  request_hash text not null,
  response_code integer not null,
  response_body jsonb,
  expires_at timestamptz not null,
  created_at timestamptz not null default now()
);
create index if not exists idx_api_idem_org on public.api_idempotency_keys(org_id);
create index if not exists idx_api_idem_expires on public.api_idempotency_keys(expires_at);

alter table public.api_idempotency_keys enable row level security;
revoke all on table public.api_idempotency_keys from public;
create policy if not exists idem_select_org on public.api_idempotency_keys
  for select using ((current_setting('request.jwt.claims', true)::jsonb ->> 'org_id')::uuid = org_id or auth.role() = 'service_role');
create policy if not exists idem_modify_org on public.api_idempotency_keys
  for all using ((current_setting('request.jwt.claims', true)::jsonb ->> 'org_id')::uuid = org_id or auth.role() = 'service_role')
  with check ((current_setting('request.jwt.claims', true)::jsonb ->> 'org_id')::uuid = org_id or auth.role() = 'service_role');

-- 5) Saved searches (owner is a user, but org-scoped)
create table if not exists public.saved_searches (
  id uuid primary key default gen_random_uuid(),
  org_id uuid not null,
  user_id uuid not null,
  name text not null,
  filters jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create index if not exists idx_saved_searches_org_user on public.saved_searches(org_id, user_id);

alter table public.saved_searches enable row level security;
revoke all on table public.saved_searches from public;
create policy if not exists saved_searches_select_owner on public.saved_searches
  for select using (
    auth.role() = 'service_role' or (
      (current_setting('request.jwt.claims', true)::jsonb ->> 'org_id')::uuid = org_id and (current_setting('request.jwt.claims', true)::jsonb ->> 'sub')::uuid = user_id
    )
  );
create policy if not exists saved_searches_modify_owner on public.saved_searches
  for all using (
    auth.role() = 'service_role' or (
      (current_setting('request.jwt.claims', true)::jsonb ->> 'org_id')::uuid = org_id and (current_setting('request.jwt.claims', true)::jsonb ->> 'sub')::uuid = user_id
    )
  ) with check (
    auth.role() = 'service_role' or (
      (current_setting('request.jwt.claims', true)::jsonb ->> 'org_id')::uuid = org_id and (current_setting('request.jwt.claims', true)::jsonb ->> 'sub')::uuid = user_id
    )
  );

-- 6) Load alerts (generated by matcher; user visible)
create table if not exists public.load_alerts (
  id uuid primary key default gen_random_uuid(),
  org_id uuid not null,
  user_id uuid not null,
  saved_search_id uuid references public.saved_searches(id) on delete cascade,
  match_type text not null default 'load',
  match_payload jsonb not null default '{}'::jsonb,
  load_id uuid,
  seen boolean not null default false,
  triggered_at timestamptz not null default now(),
  created_at timestamptz not null default now()
);
create index if not exists idx_load_alerts_org_user_time on public.load_alerts(org_id, user_id, triggered_at desc);

alter table public.load_alerts enable row level security;
revoke all on table public.load_alerts from public;
create policy if not exists load_alerts_select_owner on public.load_alerts
  for select using (
    auth.role() = 'service_role' or (
      (current_setting('request.jwt.claims', true)::jsonb ->> 'org_id')::uuid = org_id and (current_setting('request.jwt.claims', true)::jsonb ->> 'sub')::uuid = user_id
    )
  );
create policy if not exists load_alerts_modify_owner on public.load_alerts
  for update using (
    auth.role() = 'service_role' or (
      (current_setting('request.jwt.claims', true)::jsonb ->> 'org_id')::uuid = org_id and (current_setting('request.jwt.claims', true)::jsonb ->> 'sub')::uuid = user_id
    )
  ) with check (
    auth.role() = 'service_role' or (
      (current_setting('request.jwt.claims', true)::jsonb ->> 'org_id')::uuid = org_id and (current_setting('request.jwt.claims', true)::jsonb ->> 'sub')::uuid = user_id
    )
  );

-- 7) Privacy/Consent logs and Access audit (read events)
create table if not exists public.consent_logs (
  id uuid primary key default gen_random_uuid(),
  org_id uuid not null,
  user_id uuid not null,
  action text not null, -- consent_granted | consent_revoked | policy_viewed
  category text,
  purpose text,
  details jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);
create index if not exists idx_consent_org_user_time on public.consent_logs(org_id, user_id, created_at desc);

alter table public.consent_logs enable row level security;
revoke all on table public.consent_logs from public;
create policy if not exists consent_select_owner on public.consent_logs
  for select using (
    auth.role() = 'service_role' or (
      (current_setting('request.jwt.claims', true)::jsonb ->> 'org_id')::uuid = org_id and (current_setting('request.jwt.claims', true)::jsonb ->> 'sub')::uuid = user_id
    )
  );
create policy if not exists consent_insert_owner on public.consent_logs
  for insert with check (
    auth.role() = 'service_role' or (
      (current_setting('request.jwt.claims', true)::jsonb ->> 'org_id')::uuid = org_id and (current_setting('request.jwt.claims', true)::jsonb ->> 'sub')::uuid = user_id
    )
  );

create table if not exists public.access_audit (
  id bigserial primary key,
  org_id uuid not null,
  user_id uuid,
  resource text not null,
  action text not null, -- read|list|download
  meta jsonb not null default '{}'::jsonb,
  trace_id text,
  occurred_at timestamptz not null default now()
);
create index if not exists idx_access_audit_org_time on public.access_audit(org_id, occurred_at desc);

alter table public.access_audit enable row level security;
revoke all on table public.access_audit from public;
create policy if not exists access_audit_select_org on public.access_audit
  for select using (auth.role() = 'service_role' or (current_setting('request.jwt.claims', true)::jsonb ->> 'org_id')::uuid = org_id);
create policy if not exists access_audit_insert_service on public.access_audit
  for insert with check (auth.role() = 'service_role');

-- 8) Minimal helper functions
create or replace function public.fn_outbox_publish(
  p_org_id uuid,
  p_topic text,
  p_version text default '1',
  p_aggregate_type text default null,
  p_aggregate_id text default null,
  p_key text default null,
  p_payload jsonb
) returns public.outbox_events
language plpgsql
security definer
set search_path = public
as $$
DECLARE
  v_row public.outbox_events;
BEGIN
  insert into public.outbox_events(org_id, topic, version, aggregate_type, aggregate_id, key, payload)
  values (p_org_id, p_topic, coalesce(p_version,'1'), p_aggregate_type, p_aggregate_id, p_key, coalesce(p_payload,'{}'::jsonb))
  returning * into v_row;
  return v_row;
END
$$;

grant execute on function public.fn_outbox_publish(uuid, text, text, text, text, text, jsonb) to anon, authenticated, service_role;
