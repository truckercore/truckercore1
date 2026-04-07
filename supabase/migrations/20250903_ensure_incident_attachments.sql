-- Ensure attachments jsonb column exists on public.safety_incidents and helper RPC
create or replace function public.ensure_incident_attachments()
returns void
language plpgsql
security definer
as $$
begin
  if not exists (
    select 1
    from information_schema.columns
    where table_schema = 'public'
      and table_name = 'safety_incidents'
      and column_name = 'attachments'
  ) then
    alter table public.safety_incidents add column attachments jsonb default '[]'::jsonb;
  end if;
end;
$$;

-- Lock down function privileges (least privilege)
revoke all on function public.ensure_incident_attachments() from public;
grant execute on function public.ensure_incident_attachments() to service_role;

-- Ensure column exists, then enforce shape and constraints
select public.ensure_incident_attachments();

alter table public.safety_incidents
  alter column attachments set default '[]'::jsonb,
  alter column attachments set not null;

-- Add a CHECK to guarantee the JSON type is an array
do $$
begin
  if not exists (
    select 1 from pg_constraint
    where conname = 'attachments_is_array'
      and conrelid = 'public.safety_incidents'::regclass
  ) then
    alter table public.safety_incidents
      add constraint attachments_is_array
      check (jsonb_typeof(attachments) = 'array');
  end if;
end $$;
