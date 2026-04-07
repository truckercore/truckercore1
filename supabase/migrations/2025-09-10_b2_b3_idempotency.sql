-- B2/B3/C2 — Webhooks, API keys, Idempotency, and Outbox retry metadata
-- This migration augments existing Phase 0 foundations with:
-- - Retry/visibility columns on event_outbox (status, next_attempt_at)
-- - Webhook subscriptions richer schema (name, topics[], updated_at)
-- - Public API keys table with scopes and last-used tracking
-- - Server-side idempotency keys table + helper function

-- 1) event_outbox: add retry metadata and status for dead-letter visibility
alter table if exists public.event_outbox
  add column if not exists status text not null default 'pending' check (status in ('pending','delivered','dead')),
  add column if not exists next_attempt_at timestamptz;

create index if not exists idx_event_outbox_pending on public.event_outbox (status, coalesce(next_attempt_at, created_at));

-- 2) webhook_subscriptions: augment per acceptance (keep backward compatible with existing url)
alter table if exists public.webhook_subscriptions
  add column if not exists name text not null default 'default',
  add column if not exists topics text[] not null default array[]::text[],
  add column if not exists updated_at timestamptz not null default now();

-- Optional: keep url but also expose endpoint_url as alias for clarity
alter table if exists public.webhook_subscriptions
  add column if not exists endpoint_url text;

-- Backfill endpoint_url from url when null
update public.webhook_subscriptions set endpoint_url = coalesce(endpoint_url, url);

create index if not exists idx_webhook_subs_org_active on public.webhook_subscriptions (org_id, active);

-- 3) webhook_deliveries: ensure fields to support retries exist (already present from phase0)
-- Add delivered/dead convenience timestamps if helpful (optional)
alter table if exists public.webhook_deliveries
  add column if not exists delivered_at timestamptz,
  add column if not exists dead_lettered_at timestamptz;

-- 4) Public API keys table
create table if not exists public.api_keys (
  id uuid primary key default gen_random_uuid(),
  org_id uuid not null,
  name text not null,
  key_hash text not null, -- store hash only
  scopes text[] not null, -- e.g., {'read:loads','write:locations','admin:webhooks'}
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  last_used_at timestamptz null,
  is_active boolean not null default true
);

create index if not exists idx_api_keys_org_active on public.api_keys (org_id, is_active);
create index if not exists idx_api_keys_last_used on public.api_keys (last_used_at desc);

alter table public.api_keys enable row level security;
-- Service-managed (no direct end-user access). Expose via SECURITY DEFINER functions when needed.
create policy api_keys_service_only on public.api_keys for all to authenticated using (false) with check (false);

-- 5) Idempotency keys (server-side dedup for POST/PUT)
create table if not exists public.idempotency_keys (
  key text primary key,
  org_id uuid not null,
  endpoint text not null,
  request_hash text not null,
  response_code int not null,
  response_body jsonb not null,
  created_at timestamptz not null default now(),
  expires_at timestamptz not null
);

create index if not exists idx_idem_org_endpoint on public.idempotency_keys (org_id, endpoint);
create index if not exists idx_idem_expires on public.idempotency_keys (expires_at);

alter table public.idempotency_keys enable row level security;
create policy idempotency_service_only on public.idempotency_keys for all to authenticated using (false) with check (false);

-- 5.1) Helper function to upsert/get idempotent response
create or replace function public.idempotency_put_if_absent(
  p_key text,
  p_org_id uuid,
  p_endpoint text,
  p_request_hash text,
  p_response_code int,
  p_response_body jsonb,
  p_ttl_seconds int
) returns table(existed boolean, response_code int, response_body jsonb)
language plpgsql
security definer
set search_path = public
as $$
begin
  -- If exists and not expired, return existing
  return query
  with existing as (
    select true as existed, response_code, response_body
    from public.idempotency_keys
    where key = p_key and now() < expires_at
  )
  select * from existing;

  if not found then
    insert into public.idempotency_keys(key, org_id, endpoint, request_hash, response_code, response_body, expires_at)
    values (
      p_key, p_org_id, p_endpoint, p_request_hash, p_response_code, p_response_body, now() + make_interval(secs => p_ttl_seconds)
    )
    on conflict (key) do nothing;

    -- Return the row (may have been inserted by a race) if present
    return query
    select true as existed, response_code, response_body from public.idempotency_keys where key = p_key;

    -- If still not present, it means caller will proceed to compute and call this again with real response.
    if not found then
      return query select false as existed, null::int as response_code, null::jsonb as response_body;
    end if;
  end if;
end;
$$;

revoke all on function public.idempotency_put_if_absent(text, uuid, text, text, int, jsonb, int) from public;
grant execute on function public.idempotency_put_if_absent(text, uuid, text, text, int, jsonb, int) to service_role;

-- 6) Documentation breadcrumbs as comments
comment on table public.api_keys is 'Org-scoped API keys; service-managed. key_hash only, with scopes and last-used tracking.';
comment on table public.idempotency_keys is 'Server-side Idempotency-Key cache for deduplicating POST/PUT within TTL window.';
comment on table public.event_outbox is 'Durable event outbox used by delivery worker. Includes retry bookkeeping and dead-letter status.';
comment on table public.webhook_subscriptions is 'Per-org webhook endpoints with HMAC secret and topic filters.';
