create table if not exists public.rls_validation_targets(
  table_name text primary key
);

insert into public.rls_validation_targets(table_name) values
  ('tenders'),('tender_quotes'),('invoices'),('invoice_items'),('entitlements'),('user_overrides')
on conflict do nothing;

create table if not exists public.rls_validation_results(
  id bigserial primary key,
  ran_at timestamptz default now(),
  table_name text,
  has_rls boolean,
  select_policies int,
  insert_policies int,
  update_policies int,
  delete_policies int,
  notes text
);

create or replace function public.validate_rls_policies()
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  r record;
  rel oid;
  has_rls boolean;
  sel int; ins int; upd int; del int;
begin
  for r in select table_name from public.rls_validation_targets loop
    select c.oid into rel
    from pg_class c join pg_namespace n on n.oid=c.relnamespace
    where n.nspname='public' and c.relname=r.table_name;

    if rel is null then
      insert into public.rls_validation_results(table_name, has_rls, notes)
      values (r.table_name, false, 'table missing');
      continue;
    end if;

    select relrowsecurity into has_rls from pg_class where oid=rel;

    select count(*) filter (where cmd='SELECT'),
           count(*) filter (where cmd='INSERT'),
           count(*) filter (where cmd='UPDATE'),
           count(*) filter (where cmd='DELETE')
      into sel, ins, upd, del
    from pg_policies p where p.schemaname='public' and p.tablename=r.table_name;

    insert into public.rls_validation_results(table_name, has_rls, select_policies, insert_policies, update_policies, delete_policies)
    values (r.table_name, has_rls, sel, ins, upd, del);
  end loop;
end $$;
