-- docs/supabase/rls_ops_hardening.sql
-- Operational hardening pack: RLS isolation, write guards, org-scoped RPCs
-- Idempotent where possible. Run top-to-bottom in Supabase SQL editor.

set search_path = public;

-- Helpers to read current org/user from JWT claims
create or replace function public.current_org_id()
returns uuid
language sql
stable
security definer
as $$
  select nullif(current_setting('request.jwt.claims', true)::json->>'app_org_id','')::uuid;
$$;
grant execute on function public.current_org_id() to authenticated, anon;

create or replace function public.current_user_id()
returns uuid
language sql
stable
security definer
as $$
  select auth.uid();
$$;
grant execute on function public.current_user_id() to authenticated, anon;

-- Route logs RLS and RPCs
do $$
begin
  if to_regclass('public.route_logs') is not null then
    -- Enable RLS and restrict mutations
    execute 'alter table public.route_logs enable row level security';

    -- Read policy: only rows for caller''s current org
    if not exists (
      select 1 from pg_policies where schemaname='public' and tablename='route_logs' and policyname='route_logs_read_org'
    ) then
      execute $$create policy route_logs_read_org on public.route_logs for select to authenticated
               using (coalesce((org_id)::text,'') = coalesce(current_setting('request.jwt.claims', true)::json->>'app_org_id',''))$$;
    end if;

    -- Block updates/deletes for authenticated users
    if not exists (
      select 1 from pg_policies where schemaname='public' and tablename='route_logs' and policyname='route_logs_block_mutations'
    ) then
      execute $$create policy route_logs_block_mutations on public.route_logs for update to authenticated using (false) with check (false)$$;
      execute $$create policy route_logs_block_delete on public.route_logs for delete to authenticated using (false)$$;
    end if;
  end if;
end$$;

-- Telemetry events RLS and RPCs
do $$
begin
  if to_regclass('public.telemetry_events') is not null then
    execute 'alter table public.telemetry_events enable row level security';

    if not exists (
      select 1 from pg_policies where schemaname='public' and tablename='telemetry_events' and policyname='telemetry_events_read_org'
    ) then
      execute $$create policy telemetry_events_read_org on public.telemetry_events for select to authenticated
               using (coalesce((org_id)::text,'') = coalesce(current_setting('request.jwt.claims', true)::json->>'app_org_id',''))$$;
    end if;

    -- Block updates/deletes for authenticated users
    if not exists (
      select 1 from pg_policies where schemaname='public' and tablename='telemetry_events' and policyname='telemetry_events_block_mutations'
    ) then
      execute $$create policy telemetry_events_block_mutations on public.telemetry_events for update to authenticated using (false) with check (false)$$;
      execute $$create policy telemetry_events_block_delete on public.telemetry_events for delete to authenticated using (false)$$;
    end if;
  end if;
end$$;

-- RPC: insert route log with org/user derived from context; ignores spoofed org_id/user_id
create or replace function public.rpc_insert_route_log(
  p_route_id uuid,
  p_event text,
  p_payload jsonb default '{}'::jsonb
) returns uuid
language plpgsql
security definer
as $$
declare
  v_id uuid;
  v_org uuid := public.current_org_id();
  v_user uuid := public.current_user_id();
begin
  if v_org is null then
    raise exception 'ORG_NOT_SET';
  end if;

  insert into public.route_logs(org_id, route_id, event, payload, created_by)
  values (v_org, p_route_id, p_event, coalesce(p_payload, '{}'::jsonb), v_user)
  returning id into v_id;

  return v_id;
end;
$$;
revoke all on function public.rpc_insert_route_log(uuid, text, jsonb) from public;
grant execute on function public.rpc_insert_route_log(uuid, text, jsonb) to authenticated, anon;

-- RPC: log telemetry with org scoped from current_org_id()
create or replace function public.rpc_log_telemetry(
  p_kind text,
  p_payload jsonb default '{}'::jsonb
) returns void
language plpgsql
security definer
as $$
declare
  v_org uuid := public.current_org_id();
  v_user uuid := public.current_user_id();
begin
  if v_org is null then
    raise exception 'ORG_NOT_SET';
  end if;

  insert into public.telemetry_events(org_id, kind, payload, created_by)
  values (v_org, p_kind, coalesce(p_payload, '{}'::jsonb), v_user);
end;
$$;
revoke all on function public.rpc_log_telemetry(text, jsonb) from public;
grant execute on function public.rpc_log_telemetry(text, jsonb) to authenticated, anon;

-- Service-only upsert for connector_runs (Edge Functions use service role)
-- Creates/updates a run row and returns id
create or replace function connectors.svc_connector_run_upsert(
  p_org_id uuid,
  p_connector text,
  p_source text,
  p_status text default 'started',
  p_rows_processed int default 0,
  p_error text default null
) returns int
language plpgsql
security definer
as $$
declare
  v_id int;
begin
  -- Insert new run
  insert into connectors.connector_runs(org_id, connector_type, source, status, rows_processed, error)
  values (p_org_id, p_connector, p_source, coalesce(p_status,'started'), coalesce(p_rows_processed,0), p_error)
  returning id into v_id;
  return v_id;
end;
$$;
revoke all on function connectors.svc_connector_run_upsert(uuid, text, text, text, int, text) from public;
-- Only service role should call this
grant execute on function connectors.svc_connector_run_upsert(uuid, text, text, text, int, text) to service_role;

-- Explicitly revoke client table privileges on connector_runs (defense-in-depth)
do $$
begin
  if to_regclass('connectors.connector_runs') is not null then
    execute 'revoke insert, update, delete on table connectors.connector_runs from authenticated';
    execute 'revoke insert, update, delete on table connectors.connector_runs from anon';
    execute 'alter table connectors.connector_runs enable row level security';
  end if;
end$$;

-- Optional: index hints for high-volume telemetry
-- create index concurrently if not exists brin_telemetry_events_created_at on public.telemetry_events using brin(created_at);
