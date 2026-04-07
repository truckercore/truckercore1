create table if not exists public.feature_flags (
  key text primary key,
  description text
);

create table if not exists public.flag_rules (
  id uuid primary key default gen_random_uuid(),
  flag_key text references public.feature_flags(key) on delete cascade,
  tenant_id uuid,
  role text,
  enabled boolean not null,
  updated_by uuid,
  updated_at timestamptz default now()
);

create or replace function app.flag_enabled(_key text)
returns boolean language sql stable as $$
  select coalesce((
    select enabled from public.flag_rules
    where flag_key=_key
      and (tenant_id is null or tenant_id = app.current_org_id())
      and (role is null or role = app.current_role())
    order by tenant_id desc nulls last, role desc nulls last, updated_at desc
    limit 1
  ), false)
$$;
