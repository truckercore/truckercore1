-- Migration: Secure RPC wrapper for nightly learning job
-- Date: 2025-09-27

-- Ensure uuid extension (if audit needs ids elsewhere)
create extension if not exists "uuid-ossp";

-- Helper to read forwarded audit headers safely
create or replace function public.http_header(name text)
returns text
language sql
stable
as $$
  select (current_setting('request.headers', true)::jsonb ->> name)
$$;

-- Wrapper around the core learning routine.
-- Assumes your core job is run via public.run_learning_job() returning jsonb
-- If you use a different inner function, update the call below.
create or replace function public.run_nightly_job_wrapper()
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_audit_id uuid;
  v_started_at timestamptz := now();
  v_trigger text := coalesce(public.http_header('x-audit-trigger'), 'cron');
  v_forwarded_request_id text := public.http_header('x-request-id');
  v_result jsonb := '{}'::jsonb;
begin
  -- Start audit row
  insert into public.job_audit_log (job_name, status, details)
  values (
    'nightly_learning_job',
    'starting',
    jsonb_strip_nulls(jsonb_build_object(
      'trigger', v_trigger,
      'request_id', v_forwarded_request_id,
      'started_at', v_started_at
    ))
  )
  returning id into v_audit_id;

  -- Invoke the core learning job (SECURITY DEFINER function)
  -- Replace with your inner function if different.
  v_result := coalesce(public.run_learning_job(), '{}'::jsonb);

  -- Mark success
  update public.job_audit_log
  set status = 'completed',
      ran_at = now(),
      details = coalesce(details, '{}'::jsonb) || jsonb_strip_nulls(jsonb_build_object(
        'result', v_result,
        'completed_at', now()
      ))
  where id = v_audit_id;

  return jsonb_build_object('ok', true, 'result', v_result);
exception when others then
  -- Failure path with error logged
  if v_audit_id is null then
    insert into public.job_audit_log (job_name, status, details)
    values (
      'nightly_learning_job',
      'failed',
      jsonb_build_object(
        'error', SQLERRM,
        'trigger', v_trigger,
        'request_id', v_forwarded_request_id,
        'failed_at', now()
      )
    );
  else
    update public.job_audit_log
    set status = 'failed',
        ran_at = now(),
        details = coalesce(details, '{}'::jsonb) || jsonb_build_object(
          'error', SQLERRM,
          'failed_at', now()
        )
    where id = v_audit_id;
  end if;

  return jsonb_build_object('ok', false, 'error', SQLERRM);
end;
$$;

-- Lock down EXECUTE to service role only
revoke all on function public.run_nightly_job_wrapper() from public;
grant execute on function public.run_nightly_job_wrapper() to service_role;
