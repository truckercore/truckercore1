-- docs/supabase/org_manifest_versions.sql
-- Manifest versioning rule (monotonic per org) with HMAC endpoints support.
-- Idempotent and safe to re-run.

create extension if not exists pgcrypto;

-- 1) Monotonic version table per org
create table if not exists public.org_manifest_versions (
  org_id uuid primary key,
  last_version bigint not null default 0,
  updated_at timestamptz not null default now()
);

-- 2) Check-and-set function: rejects stale or equal versions
create or replace function public.fn_manifest_check_version(p_org_id uuid, p_version bigint)
returns void
language plpgsql
security definer
as $$
declare v_last bigint;
begin
  select last_version into v_last from public.org_manifest_versions where org_id = p_org_id for update;
  if not found then
    insert into public.org_manifest_versions(org_id, last_version)
    values (p_org_id, p_version);
    return;
  end if;
  if p_version <= v_last then
    raise exception 'stale_manifest_version' using hint = format('got=%s expected>%s', p_version, v_last);
  end if;
  update public.org_manifest_versions
  set last_version = p_version, updated_at = now()
  where org_id = p_org_id;
end $$;

revoke all on function public.fn_manifest_check_version(uuid,bigint) from public;
grant execute on function public.fn_manifest_check_version(uuid,bigint) to service_role;
