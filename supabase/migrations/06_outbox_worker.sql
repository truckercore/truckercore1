-- 06_outbox_worker.sql
-- Week 4 — Outbox worker RPCs for atomic leasing, attempts/backoff, delivery, and DLQ
-- These SECURITY DEFINER functions are intended to be called by the worker using the service role.

-- 0) Safety: ensure table exists (created in 05_week1_foundations.sql)
create table if not exists public.outbox_events (
  id bigserial primary key,
  org_id uuid not null,
  topic text not null,
  version text not null default '1',
  aggregate_type text,
  aggregate_id text,
  key text,
  payload jsonb not null,
  status text not null default 'pending',
  attempts integer not null default 0,
  next_attempt_at timestamptz,
  lease_until timestamptz,
  last_status_code integer,
  last_error text,
  delivered_at timestamptz,
  created_at timestamptz not null default now()
);

-- 1) Claim pending with lease (SKIP LOCKED pattern)
create or replace function public.fn_outbox_claim_pending(
  p_limit integer default 100,
  p_lease_seconds integer default 30
) returns setof public.outbox_events
language plpgsql
security definer
set search_path = public
as $$
declare
  v_now timestamptz := now();
  v_lease_until timestamptz := now() + make_interval(secs => greatest(1, p_lease_seconds));
begin
  return query
  with candidates as (
    select id
    from public.outbox_events
    where status = 'pending'
      and coalesce(next_attempt_at, now()) <= now()
      and (lease_until is null or lease_until < now())
    order by coalesce(next_attempt_at, v_now) asc, created_at asc
    limit p_limit
    for update skip locked
  ), upd as (
    update public.outbox_events e
    set lease_until = v_lease_until
    from candidates c
    where e.id = c.id
    returning e.*
  )
  select * from upd;
end
$$;
comment on function public.fn_outbox_claim_pending(integer, integer) is 'Atomically claims pending outbox rows by setting lease_until; returns claimed rows.';

-- 2) Record an attempt and return attempts count
create or replace function public.fn_outbox_record_attempt(
  p_id bigint,
  p_status integer default null,
  p_error text default null
) returns integer
language plpgsql
security definer
set search_path = public
as $$
declare v_attempts integer; begin
  update public.outbox_events
  set attempts = attempts + 1,
      last_status_code = p_status,
      last_error = p_error
  where id = p_id
  returning attempts into v_attempts;
  return coalesce(v_attempts, 0);
end $$;
comment on function public.fn_outbox_record_attempt(bigint, integer, text) is 'Increments attempts and stores last_status_code/error; returns attempts.';

-- 3) Schedule retry: set next_attempt_at and clear lease
create or replace function public.fn_outbox_schedule_retry(
  p_id bigint,
  p_retry_at timestamptz
) returns void
language sql
security definer
set search_path = public
as $$
  update public.outbox_events set next_attempt_at = p_retry_at, lease_until = null where id = p_id;
$$;
comment on function public.fn_outbox_schedule_retry(bigint, timestamptz) is 'Schedules next attempt and clears lease.';

-- 4) Mark delivered and clear lease
create or replace function public.fn_outbox_mark_delivered(
  p_id bigint
) returns void
language sql
security definer
set search_path = public
as $$
  update public.outbox_events set status = 'delivered', delivered_at = now(), lease_until = null where id = p_id;
$$;
comment on function public.fn_outbox_mark_delivered(bigint) is 'Marks an outbox row delivered and clears lease.';

-- 5) Mark dead (DLQ) and clear lease
create or replace function public.fn_outbox_mark_dead(
  p_id bigint,
  p_status integer default null,
  p_error text default null
) returns void
language sql
security definer
set search_path = public
as $$
  update public.outbox_events set status = 'dead', last_status_code = p_status, last_error = p_error, lease_until = null where id = p_id;
$$;
comment on function public.fn_outbox_mark_dead(bigint, integer, text) is 'Marks an outbox row as dead-letter (DLQ).';

-- 6) Admin helpers: list DLQ and replay
create or replace function public.fn_outbox_list_dead(
  p_org_id uuid,
  p_topic text default null,
  p_limit integer default 100
) returns setof public.outbox_events
language sql
security definer
set search_path = public
as $$
  select * from public.outbox_events
  where org_id = p_org_id and status = 'dead'
    and (p_topic is null or topic = p_topic)
  order by created_at desc
  limit p_limit;
$$;
comment on function public.fn_outbox_list_dead(uuid, text, integer) is 'Lists DLQ events for an org, optionally filtered by topic.';

create or replace function public.fn_outbox_replay(
  p_org_id uuid,
  p_ids bigint[] default null,
  p_topic text default null,
  p_limit integer default 50
) returns integer
language plpgsql
security definer
set search_path = public
as $$
declare v_count integer := 0; begin
  if p_ids is not null then
    update public.outbox_events
    set status = 'pending', next_attempt_at = now(), lease_until = null
    where org_id = p_org_id and id = any(p_ids)
      and status = 'dead'
    returning 1 into v_count;
    get diagnostics v_count = row_count;
    return v_count;
  end if;
  with picked as (
    select id from public.outbox_events
     where org_id = p_org_id and status = 'dead'
       and (p_topic is null or topic = p_topic)
     order by created_at asc
     limit p_limit
  )
  update public.outbox_events e
  set status = 'pending', next_attempt_at = now(), lease_until = null
  from picked p
  where e.id = p.id;
  get diagnostics v_count = row_count;
  return v_count;
end $$;
comment on function public.fn_outbox_replay(uuid, bigint[], text, integer) is 'Re-queues DLQ events for replay; returns count.';

-- Grants
grant execute on function public.fn_outbox_claim_pending(integer, integer) to service_role;
grant execute on function public.fn_outbox_record_attempt(bigint, integer, text) to service_role;
grant execute on function public.fn_outbox_schedule_retry(bigint, timestamptz) to service_role;
grant execute on function public.fn_outbox_mark_delivered(bigint) to service_role;
grant execute on function public.fn_outbox_mark_dead(bigint, integer, text) to service_role;
grant execute on function public.fn_outbox_list_dead(uuid, text, integer) to service_role;
grant execute on function public.fn_outbox_replay(uuid, bigint[], text, integer) to service_role;
