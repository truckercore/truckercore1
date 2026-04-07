create table if not exists public.rls_test_cases(
  id bigserial primary key,
  table_name regclass not null,
  filter text default 'true',
  claims jsonb,
  expect_min int not null,
  expect_max int,
  note text
);

create table if not exists public.rls_test_results(
  id bigserial primary key,
  ran_at timestamptz default now(),
  table_name text,
  filter text,
  claims jsonb,
  observed int,
  expect_min int,
  expect_max int,
  pass boolean,
  note text
);

create or replace function public.rls_run_all_tests()
returns int
language plpgsql
security definer
set search_path=public
as $$
declare r record; n int:=0; obs int; ok bool;
begin
  for r in select * from public.rls_test_cases loop
    obs := rls_simulate(r.table_name, r.filter, r.claims);
    ok := (obs >= r.expect_min) and (r.expect_max is null or obs <= r.expect_max);
    insert into public.rls_test_results(table_name,filter,claims,observed,expect_min,expect_max,pass,note)
    values (r.table_name::text,r.filter,r.claims,obs,r.expect_min,r.expect_max,ok,r.note);
    n := n + 1;
  end loop;
  return n;
end $$;
