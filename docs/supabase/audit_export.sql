-- Audit export RPC (v1)
-- Location: docs/supabase/audit_export.sql
-- Exposes a time-bounded export of audit events as setof jsonb.
-- Adjust the SELECT to match your audit/audit-like tables.

create or replace function public.fn_audit_export(p_org uuid, p_from text, p_to text)
returns setof jsonb
language sql
stable
as $$
  with bounds as (
    select (p_from || 'T00:00:00Z')::timestamptz as from_at,
           (p_to   || 'T23:59:59Z')::timestamptz as to_at
  )
  -- Example: export from action_audit when present; fallback to connector_jobs minimal trail
  select to_jsonb(a.*)
  from public.action_audit a, bounds b
  where a.org_id = p_org and a.created_at between b.from_at and b.to_at
  union all
  select to_jsonb(j.*)
  from public.connector_jobs j, bounds b
  where j.org_id = p_org and j.created_at between b.from_at and b.to_at
$$;
