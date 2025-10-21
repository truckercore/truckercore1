-- docs/sql/audit_entitlements.sql

-- 1. History sink
create table if not exists public.audit_log (
  id bigserial primary key,
  at timestamptz not null default now(),
  actor_user uuid null,
  actor_org uuid null,
  action text not null check (action in ('insert','update','delete')),
  table_name text not null,
  row_id uuid null,
  before jsonb null,
  after jsonb null,
  -- Compatibility columns for external queries/tools
  created_at timestamptz not null default now(),
  entity text,
  entity_id text
);
create index if not exists idx_audit_time on public.audit_log (at desc);
create index if not exists idx_audit_table on public.audit_log (table_name, at desc);
create index if not exists idx_audit_created_at on public.audit_log (created_at desc);
create index if not exists idx_audit_entity on public.audit_log (entity, created_at desc);
create index if not exists idx_audit_entity_id on public.audit_log (entity_id, created_at desc);
alter table public.audit_log enable row level security;
-- Read limited to org scope; service role can read/write
create policy audit_read_org on public.audit_log
for select to authenticated
using (actor_org::text = coalesce(current_setting('request.jwt.claims', true)::json->>'app_org_id',''));
grant select on public.audit_log to authenticated;
revoke insert, update, delete on public.audit_log from authenticated;

-- 2. Helpers to capture actor from JWT (RLS-friendly)
create or replace function public.current_actor_user() returns uuid
language sql stable as $$
  select nullif(auth.uid()::text, '')::uuid
$$;

create or replace function public.current_actor_org() returns uuid
language sql stable as $$
  select nullif(auth.jwt()->>'app_org_id','')::uuid
$$;

-- 2b. Backfill compatibility columns for existing rows (no-op if empty)
-- update public.audit_log set created_at = at where created_at is distinct from at;
-- update public.audit_log set entity = table_name where entity is null;

-- 3. Generic row-level logger (security definer, fixed search_path)
create or replace function public.log_row_change() returns trigger
language plpgsql security definer set search_path=public as $$
begin
  insert into public.audit_log (actor_user, actor_org, action, table_name, row_id, before, after, created_at, entity, entity_id)
  values (
    public.current_actor_user(),
    public.current_actor_org(),
    lower(tg_op)::text,
    tg_table_name,
    coalesce((new).id, (old).id),
    case when tg_op in ('UPDATE','DELETE') then to_jsonb(old) else null end,
    case when tg_op in ('INSERT','UPDATE') then to_jsonb(new) else null end,
    now(),
    tg_table_name,
    coalesce((new).id, (old).id)::text
  );
  return coalesce(new, old);
end $$;

-- 4. Attach triggers (adjust table names if different in your schema)
drop trigger if exists tr_audit_entitlements on public.entitlements;
create trigger tr_audit_entitlements
after insert or update or delete on public.entitlements
for each row execute function public.log_row_change();

drop trigger if exists tr_audit_user_overrides on public.user_overrides;
create trigger tr_audit_user_overrides
after insert or update or delete on public.user_overrides
for each row execute function public.log_row_change();

drop trigger if exists tr_audit_org_settings on public.org_settings;
create trigger tr_audit_org_settings
after insert or update or delete on public.org_settings
for each row execute function public.log_row_change();
