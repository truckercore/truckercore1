-- 01_enterprise_audit_log.sql
-- Enterprise-grade tamper-evident audit log with strict RLS and SECURITY DEFINER insert function.
-- Retention policy (plan): Enterprise 365d, others 90d. Weekly purge job to be added later.

-- 1) Core table
create table if not exists public.enterprise_audit_log (
  id uuid primary key default gen_random_uuid(),
  org_id uuid not null,
  actor_user_id uuid,
  action text not null,                 -- e.g., 'assign_driver','request_load','update_alert'
  entity_type text not null,            -- e.g., 'load','driver','alert'
  entity_id text not null,              -- short id or UUID as text
  description text default '',
  details jsonb default '{}'::jsonb,    -- any extra fields
  trace_id text,                        -- propagated from API/gateway headers or generated
  -- Tamper-evident hash chain
  prev_hash text,                       -- hash of previous record for same org
  record_hash text,                     -- hash of (org_id, actor_user_id, action, entity_type, entity_id, description, details, trace_id, prev_hash, created_at)
  created_at timestamptz not null default now()
);
create index if not exists idx_eal_org_time on public.enterprise_audit_log(org_id, created_at desc);
create index if not exists idx_eal_action_time on public.enterprise_audit_log(action, created_at desc);
create index if not exists idx_eal_trace on public.enterprise_audit_log(org_id, trace_id);

comment on table public.enterprise_audit_log is 'Tamper-evident audit log per org with hash chain (prev_hash, record_hash). Insert-only via function.';

-- 2) Idempotency table to avoid duplicate effects on sensitive RPCs
create table if not exists public.org_idempotency_keys (
  org_id uuid not null,
  action text not null,
  idempotency_key text not null,
  first_seen_at timestamptz not null default now(),
  primary key(org_id, action, idempotency_key)
);
comment on table public.org_idempotency_keys is 'Tracks used idempotency keys per org+action to ensure idempotent RPCs.';

-- 3) Helper to compute hash deterministically
create or replace function public.fn_eal_compute_hash(
  p_org_id uuid,
  p_actor_user_id uuid,
  p_action text,
  p_entity_type text,
  p_entity_id text,
  p_description text,
  p_details jsonb,
  p_trace_id text,
  p_prev_hash text,
  p_created_at timestamptz
) returns text language sql as $$
  select encode(digest(
    coalesce(p_org_id::text,'') || '|' ||
    coalesce(p_actor_user_id::text,'') || '|' ||
    coalesce(p_action,'') || '|' ||
    coalesce(p_entity_type,'') || '|' ||
    coalesce(p_entity_id,'') || '|' ||
    coalesce(p_description,'') || '|' ||
    coalesce(p_details::text,'') || '|' ||
    coalesce(p_trace_id,'') || '|' ||
    coalesce(p_prev_hash,'') || '|' ||
    (extract(epoch from p_created_at)::bigint)::text
  , 'sha256'), 'hex');
$$;

-- 4) SECURITY DEFINER insert function that maintains the chain per org
create or replace function public.fn_enterprise_audit_insert(
  p_org_id uuid,
  p_actor_user_id uuid,
  p_action text,
  p_entity_type text,
  p_entity_id text,
  p_description text default '',
  p_details jsonb default '{}'::jsonb,
  p_trace_id text default null
) returns public.enterprise_audit_log
language plpgsql
security definer
set search_path = public
as $$
DECLARE
  v_prev_hash text;
  v_created_at timestamptz := now();
  v_record public.enterprise_audit_log;
BEGIN
  -- Get previous hash in org chain (most recent row)
  select record_hash into v_prev_hash
  from public.enterprise_audit_log
  where org_id = p_org_id
  order by created_at desc
  limit 1;

  -- Insert row with computed record_hash
  insert into public.enterprise_audit_log(
    org_id, actor_user_id, action, entity_type, entity_id, description, details, trace_id, prev_hash, record_hash, created_at
  ) values (
    p_org_id, p_actor_user_id, p_action, p_entity_type, p_entity_id, p_description, p_details, p_trace_id,
    v_prev_hash,
    public.fn_eal_compute_hash(p_org_id, p_actor_user_id, p_action, p_entity_type, p_entity_id, p_description, p_details, p_trace_id, v_prev_hash, v_created_at),
    v_created_at
  ) returning * into v_record;

  return v_record;
END
$$;
comment on function public.fn_enterprise_audit_insert is 'Insert into enterprise_audit_log while maintaining tamper-evident hash chain per org.';

-- 5) RLS: org-scoped SELECT, no UPDATE/DELETE, inserts via function only
alter table public.enterprise_audit_log enable row level security;

-- Baseline policies: deny by default
revoke all on table public.enterprise_audit_log from public;

-- Allow select within org scope, assuming request.jwt contains org_id in claim 'org_id'
create policy if not exists eal_select_org_scope on public.enterprise_audit_log
  for select using (
    auth.role() = 'service_role' or
    (current_setting('request.jwt.claims', true)::jsonb ? 'org_id' and
     (current_setting('request.jwt.claims', true)::jsonb ->> 'org_id')::uuid = org_id)
  );

-- Hard block updates/deletes (no policies created); additionally revoke privileges
revoke update, delete, insert on table public.enterprise_audit_log from public;

-- Optional view for Activity UI (stable projection)
create or replace view public.v_enterprise_activity as
select
  id,
  created_at as occurred_at,
  org_id,
  actor_user_id,
  action,
  entity_type,
  entity_id,
  description,
  details,
  trace_id,
  prev_hash,
  record_hash
from public.enterprise_audit_log;

-- 6) Verification helper (recompute hash and compare)
create or replace function public.fn_eal_verify_row(p_id uuid)
returns boolean language sql stable as $$
  select record_hash = public.fn_eal_compute_hash(org_id, actor_user_id, action, entity_type, entity_id, description, details, trace_id, prev_hash, created_at)
  from public.enterprise_audit_log where id = p_id
$$;

-- 7) Example RPC for a sensitive action pattern (skeleton)
-- This example demonstrates idempotency and audit; adapt to domain as needed.
create or replace function public.rpc_assign_driver(
  p_org_id uuid,
  p_actor_user_id uuid,
  p_driver_id uuid,
  p_load_id uuid,
  p_idempotency_key text,
  p_trace_id text default null
) returns jsonb
language plpgsql
security definer
set search_path = public
as $$
DECLARE
  v_exists boolean;
  v_result jsonb;
BEGIN
  if coalesce(p_org_id, '00000000-0000-0000-0000-000000000000')::text = '00000000-0000-0000-0000-000000000000' then
    raise exception 'org_id required';
  end if;
  if p_idempotency_key is null or length(p_idempotency_key) < 8 then
    raise exception 'idempotency_key too short';
  end if;

  -- Check idempotency
  select true into v_exists from public.org_idempotency_keys where org_id=p_org_id and action='assign_driver' and idempotency_key=p_idempotency_key;
  if v_exists then
    -- Return a normalized response indicating no-op
    return jsonb_build_object('status','ok','idempotent',true);
  end if;

  -- TODO: perform domain validations and write (omitted in this skeleton)
  -- e.g., ensure driver belongs to org and load is assignable

  -- Mark idempotency key
  insert into public.org_idempotency_keys(org_id, action, idempotency_key) values (p_org_id, 'assign_driver', p_idempotency_key)
  on conflict do nothing;

  -- Audit after successful write
  perform public.fn_enterprise_audit_insert(
    p_org_id,
    p_actor_user_id,
    'assign_driver',
    'load',
    p_load_id::text,
    'Assigned driver ' || p_driver_id::text || ' to load ' || p_load_id::text,
    jsonb_build_object('driver_id', p_driver_id::text, 'load_id', p_load_id::text),
    p_trace_id
  );

  v_result := jsonb_build_object('status','ok','idempotent',false);
  return v_result;
END
$$;
comment on function public.rpc_assign_driver is 'Example sensitive RPC with idempotency and audit logging. Replace domain write with real logic.';

-- 8) Grants for RPCs to be callable by authenticated users
grant execute on function public.fn_enterprise_audit_insert(uuid, uuid, text, text, text, text, jsonb, text) to anon, authenticated, service_role;
grant execute on function public.rpc_assign_driver(uuid, uuid, uuid, uuid, text, text) to anon, authenticated, service_role;

-- 9) RLS note: Inserts to enterprise_audit_log should only happen via function; do not grant direct insert to regular roles.
