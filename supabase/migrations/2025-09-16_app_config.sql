-- 2025-09-16_app_config.sql
-- Application configuration storage and RPCs
-- Usage patterns supported:
--   - Read all for admin UI:           select public.get_app_config();
--   - Read by namespace/prefix:        select public.get_app_config_by_prefix('hos.');
--   - Update with concurrency check:   select public.set_app_config('hos.limits', '{"drive_limit_minutes":600}'::jsonb, '<prev_updated_at>'::timestamptz);
--   - Patch (deep-merge) values:       select public.patch_app_config('ranker.thresholds', '{"delay_secs":240}'::jsonb, null);
--
-- Security:
--   - Table is RLS protected and not directly writable by authenticated users.
--   - Functions are SECURITY DEFINER, owned by app_owner, with locked search_path.
--   - Writes allowed only to service_role or users whose JWT app_roles contain admin/owner.
--   - Error messages use application-level codes (e.g., STALE_WRITE) without schema leakage.

begin;

set search_path = public;

-- 1) Table
create table if not exists public.app_config (
  key text primary key,
  value jsonb not null default '{}'::jsonb,
  updated_at timestamptz not null default now(),
  updated_by uuid null
);

comment on table public.app_config is 'Key/value application configuration with optimistic concurrency.';
comment on column public.app_config.key is 'Namespaced key, e.g., hos.limits, ranker.thresholds';

-- Helpful index for prefix scans (btree still used for LIKE 'prefix%')
create index if not exists idx_app_config_key on public.app_config(key);

-- RLS: enable and restrict direct access
alter table public.app_config enable row level security;

-- Read-only policy (optional): allow authenticated to read
create policy if not exists app_config_read on public.app_config
for select to authenticated
using (true);

-- No insert/update/delete policies for authenticated (writes via RPC only)

-- 2) Helper: deep merge jsonb (right-hand wins); merges objects recursively; arrays are replaced by RHS
create or replace function public.jsonb_deep_merge(a jsonb, b jsonb)
returns jsonb
language sql
immutable
as $$
  select
    case
      when a is null then coalesce(b, 'null'::jsonb)
      when b is null then a
      when jsonb_typeof(a) <> 'object' or jsonb_typeof(b) <> 'object' then b
      else (
        select jsonb_object_agg(key, value)
        from (
          select key,
                 case
                   when a->key is null then b->key
                   when b->key is null then a->key
                   when jsonb_typeof(a->key) = 'object' and jsonb_typeof(b->key) = 'object'
                     then public.jsonb_deep_merge(a->key, b->key)
                   else b->key
                 end as value
          from (
            select distinct key from (
              select jsonb_object_keys(a) as key
              union all
              select jsonb_object_keys(b) as key
            ) s
          ) k
        ) t
      )
    end
$$;

comment on function public.jsonb_deep_merge(jsonb, jsonb) is 'Deep merge two jsonb objects; arrays are replaced by RHS.';

-- 3) Auth helper: is current user an admin/owner (based on JWT app_roles) or service_role?
create or replace function public._is_app_admin()
returns boolean
language plpgsql
stable
set search_path = public, pg_temp
as $$
declare
  v_claims jsonb := nullif(current_setting('request.jwt.claims', true), '')::jsonb;
  v_roles jsonb := coalesce(v_claims->'app_roles', '[]'::jsonb);
  v_role text;
  v_is_service boolean := coalesce(current_setting('role', true), '') = 'service_role';
begin
  if v_is_service then
    return true;
  end if;
  if jsonb_typeof(v_roles) = 'array' then
    for v_role in select value::text from jsonb_array_elements_text(v_roles) loop
      if v_role in ('admin','owner') then
        return true;
      end if;
    end loop;
  end if;
  return false;
end;
$$;

comment on function public._is_app_admin() is 'Returns true if caller is service_role or JWT app_roles contains admin/owner.';

-- 4) Read all as jsonb: { key: { value: <jsonb>, updated_at: <ts> }, ... }
create or replace function public.get_app_config()
returns jsonb
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  return (
    select coalesce(jsonb_object_agg(key, jsonb_build_object('value', value, 'updated_at', updated_at)), '{}'::jsonb)
    from public.app_config
  );
end;
$$;

-- 5) Read by prefix as jsonb
create or replace function public.get_app_config_by_prefix(p_prefix text)
returns jsonb
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  return (
    select coalesce(jsonb_object_agg(key, jsonb_build_object('value', value, 'updated_at', updated_at)), '{}'::jsonb)
    from public.app_config
    where key like p_prefix || '%'
  );
end;
$$;

-- 6) Set with optimistic concurrency; returns the updated row
create or replace function public.set_app_config(
  p_key text,
  p_value jsonb,
  p_prev_updated_at timestamptz
)
returns table(key text, value jsonb, updated_at timestamptz)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not public._is_app_admin() then
    raise exception 'FORBIDDEN' using errcode = 'P0001', message = 'FORBIDDEN';
  end if;

  -- Concurrency check
  if p_prev_updated_at is not null then
    perform 1 from public.app_config where key = p_key and updated_at = p_prev_updated_at;
    if not found then
      raise exception 'STALE_WRITE' using errcode = 'P0001', message = 'STALE_WRITE';
    end if;
  end if;

  -- Upsert
  insert into public.app_config as c(key, value, updated_at, updated_by)
  values (p_key, coalesce(p_value, '{}'::jsonb), now(), auth.uid())
  on conflict (key)
  do update set value = excluded.value, updated_at = now(), updated_by = auth.uid()
  returning c.key, c.value, c.updated_at
  into key, value, updated_at;

  return;
end;
$$;

-- 7) Patch (deep merge) existing jsonb value; returns updated row
create or replace function public.patch_app_config(
  p_key text,
  p_patch jsonb,
  p_prev_updated_at timestamptz default null
)
returns table(key text, value jsonb, updated_at timestamptz)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_old jsonb := '{}'::jsonb;
  v_new jsonb := '{}'::jsonb;
begin
  if not public._is_app_admin() then
    raise exception 'FORBIDDEN' using errcode = 'P0001', message = 'FORBIDDEN';
  end if;

  select coalesce(value, '{}'::jsonb) into v_old from public.app_config where key = p_key;

  if p_prev_updated_at is not null then
    perform 1 from public.app_config where key = p_key and updated_at = p_prev_updated_at;
    if not found then
      raise exception 'STALE_WRITE' using errcode = 'P0001', message = 'STALE_WRITE';
    end if;
  end if;

  v_new := public.jsonb_deep_merge(v_old, coalesce(p_patch, '{}'::jsonb));

  insert into public.app_config as c(key, value, updated_at, updated_by)
  values (p_key, v_new, now(), auth.uid())
  on conflict (key)
  do update set value = v_new, updated_at = now(), updated_by = auth.uid()
  returning c.key, c.value, c.updated_at
  into key, value, updated_at;

  return;
end;
$$;

-- 8) Ownership and grants hygiene
-- Ensure app_owner exists (from earlier hygiene migration); make it owner when possible.
do $$ begin
  if exists (select 1 from pg_roles where rolname = 'app_owner') then
    begin
      alter table public.app_config owner to app_owner;
    exception when insufficient_privilege then null; end;
    begin alter function public.jsonb_deep_merge(jsonb, jsonb) owner to app_owner; exception when others then null; end;
    begin alter function public._is_app_admin() owner to app_owner; exception when others then null; end;
    begin alter function public.get_app_config() owner to app_owner; exception when others then null; end;
    begin alter function public.get_app_config_by_prefix(text) owner to app_owner; exception when others then null; end;
    begin alter function public.set_app_config(text, jsonb, timestamptz) owner to app_owner; exception when others then null; end;
    begin alter function public.patch_app_config(text, jsonb, timestamptz) owner to app_owner; exception when others then null; end;
  end if;
end $$;

-- Lock down function execution privileges
revoke all on function public.get_app_config() from public;
revoke all on function public.get_app_config_by_prefix(text) from public;
revoke all on function public.set_app_config(text, jsonb, timestamptz) from public;
revoke all on function public.patch_app_config(text, jsonb, timestamptz) from public;
revoke all on function public._is_app_admin() from public;
revoke all on function public.jsonb_deep_merge(jsonb, jsonb) from public;

-- Reads: allow authenticated + service_role
grant execute on function public.get_app_config() to authenticated, service_role;
grant execute on function public.get_app_config_by_prefix(text) to authenticated, service_role;

-- Writes: allow authenticated (function enforces admin) and service_role
grant execute on function public.set_app_config(text, jsonb, timestamptz) to authenticated, service_role;
grant execute on function public.patch_app_config(text, jsonb, timestamptz) to authenticated, service_role;

commit;