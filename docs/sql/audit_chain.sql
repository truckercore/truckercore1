-- docs/sql/audit_chain.sql
create extension if not exists pgcrypto;

alter table public.audit_log
  add column if not exists hash text,
  add column if not exists at timestamptz default now();

create or replace function public.audit_log_chain()
returns trigger
language plpgsql
as $$
declare prev text;
begin
  select hash into prev from public.audit_log order by at desc limit 1;
  new.hash := encode(digest(coalesce(prev,'') || row_to_json(new)::text, 'sha256'),'hex');
  return new;
end $$;

drop trigger if exists tr_audit_chain on public.audit_log;
create trigger tr_audit_chain
  before insert on public.audit_log
  for each row execute function public.audit_log_chain();
