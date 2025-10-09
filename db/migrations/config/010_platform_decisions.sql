begin;

create table if not exists public.platform_decisions (
  org_id uuid null,     -- null = global default
  config jsonb not null,
  updated_by uuid,
  updated_at timestamptz not null default now(),
  primary key (org_id)
);

create view if not exists public.v_decisions_effective as
select coalesce(pd.org_id, '00000000-0000-0000-0000-000000000000'::uuid) as org_id, pd.config
from public.platform_decisions pd;

-- simple audit; assumes audit_events table exists
create or replace function public.audit_platform_decisions()
returns trigger language plpgsql as $$
begin
  insert into public.audit_events(actor, action, entity, entity_id, metadata)
  values (new.updated_by, 'decisions_update', 'platform_decisions', coalesce(new.org_id, '00000000-0000-0000-0000-000000000000'::uuid), jsonb_build_object('config', new.config));
  return new;
end; $$;

drop trigger if exists trg_audit_platform_decisions on public.platform_decisions;
create trigger trg_audit_platform_decisions
after insert or update on public.platform_decisions
for each row execute procedure public.audit_platform_decisions();

commit;
