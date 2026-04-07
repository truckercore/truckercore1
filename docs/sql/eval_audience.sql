-- docs/sql/eval_audience.sql
create or replace function public.eval_audience(p_sql text)
returns table(id uuid)
language plpgsql
security definer
set search_path=public
as $$
begin
  return query execute format('select id from public.users where %s', p_sql);
end $$;

create or replace function public.preview_announcement_audience(p_filter text)
returns int
language plpgsql
security definer
set search_path=public
as $$
declare c int;
begin
  select count(*) into c from public.eval_audience(p_filter);
  return c;
end $$;
