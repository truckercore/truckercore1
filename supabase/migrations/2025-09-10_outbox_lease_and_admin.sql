-- Outbox leasing, delivery bookkeeping, and admin helpers
-- Ensures multi-worker safety and provides DLQ replay/test-delivery scaffolding via SQL functions.

-- 1) Add leasing column (already present as next_attempt_at) and ensure attempt/bookkeeping fields exist
alter table if exists public.event_outbox
  add column if not exists lease_until timestamptz;

comment on column public.event_outbox.lease_until is 'Leased by a worker until this timestamp to avoid duplicate processing across workers.';

-- Helpful index for leasing
create index if not exists idx_event_outbox_lease on public.event_outbox (status, coalesce(lease_until, next_attempt_at, created_at));

-- 2) Claim a batch with leasing (atomic)
create or replace function public.outbox_claim_batch(p_limit int, p_lease_seconds int)
returns setof public.event_outbox
language plpgsql
security definer
set search_path = public
as $$
begin
  return query
  with to_claim as (
    select id
    from public.event_outbox
    where status = 'pending'
      and (lease_until is null or lease_until <= now())
      and (next_attempt_at is null or next_attempt_at <= now())
    order by coalesce(next_attempt_at, created_at)
    limit p_limit
    for update skip locked
  ), upd as (
    update public.event_outbox e
    set lease_until = now() + make_interval(secs => p_lease_seconds),
        delivery_attempts = e.delivery_attempts + 1
    from to_claim c
    where e.id = c.id
    returning e.*
  )
  select * from upd;
end;
$$;

revoke all on function public.outbox_claim_batch(int, int) from public;
grant execute on function public.outbox_claim_batch(int, int) to service_role;

-- 3) Record delivery attempt and schedule retry
create or replace function public.outbox_record_attempt(
  p_outbox_id uuid,
  p_subscription_id uuid,
  p_status_code int,
  p_error text,
  p_next_delay_seconds int,
  p_dead boolean default false
) returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.webhook_deliveries (outbox_id, subscription_id, attempt, status, response_code, error, next_attempt_at, created_at)
  values (
    p_outbox_id,
    p_subscription_id,
    (select delivery_attempts from public.event_outbox where id = p_outbox_id),
    case when p_dead then 'failed' else case when p_status_code between 200 and 299 then 'success' else 'pending' end end,
    p_status_code,
    p_error,
    case when p_dead then null else now() + make_interval(secs => p_next_delay_seconds) end,
    now()
  );

  update public.event_outbox
  set last_status_code = p_status_code,
      last_error = p_error,
      next_attempt_at = case when p_dead then null else now() + make_interval(secs => p_next_delay_seconds) end,
      lease_until = null,
      status = case when p_dead then 'dead' else status end
  where id = p_outbox_id;

  if p_dead then
    update public.webhook_deliveries set dead_lettered_at = now() where outbox_id = p_outbox_id and created_at = (
      select max(created_at) from public.webhook_deliveries where outbox_id = p_outbox_id
    );
  end if;
end;
$$;

revoke all on function public.outbox_record_attempt(uuid, uuid, int, text, int, boolean) from public;
grant execute on function public.outbox_record_attempt(uuid, uuid, int, text, int, boolean) to service_role;

-- 4) Mark delivered
create or replace function public.outbox_mark_delivered(p_outbox_id uuid) returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  update public.event_outbox
  set status = 'delivered', delivered_at = now(), lease_until = null, next_attempt_at = null, last_error = null
  where id = p_outbox_id;
end;
$$;

revoke all on function public.outbox_mark_delivered(uuid) from public;
grant execute on function public.outbox_mark_delivered(uuid) to service_role;

-- 5) DLQ replay helper: reset status for a single dead event
create or replace function public.outbox_replay_dead(p_outbox_id uuid) returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  update public.event_outbox
  set status = 'pending', next_attempt_at = now(), lease_until = null
  where id = p_outbox_id and status = 'dead';
end;
$$;

revoke all on function public.outbox_replay_dead(uuid) from public;
grant execute on function public.outbox_replay_dead(uuid) to service_role;

-- 6) Secret rotation support on webhook_subscriptions (overlap window)
alter table if exists public.webhook_subscriptions
  add column if not exists secret_next text,
  add column if not exists secret_next_expires_at timestamptz,
  add column if not exists max_in_flight int not null default 2;

comment on column public.webhook_subscriptions.secret_next is 'Optional next secret used during rotation overlap. Send dual signatures until secret_next_expires_at.';
comment on column public.webhook_subscriptions.secret_next_expires_at is 'When set in the future, worker should include alternate signature using secret_next until this time.';
comment on column public.webhook_subscriptions.max_in_flight is 'Concurrency cap per subscriber to avoid piling up requests.';

-- 7) Admin helper to pause/resume
create or replace function public.webhook_set_active(p_subscription_id uuid, p_active boolean) returns void
language sql
security definer
set search_path = public
as $$
  update public.webhook_subscriptions set active = p_active, updated_at = now() where id = p_subscription_id;
$$;

revoke all on function public.webhook_set_active(uuid, boolean) from public;
grant execute on function public.webhook_set_active(uuid, boolean) to service_role;
