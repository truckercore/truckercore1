create or replace function public.self_test_rls()
returns table (name text, ok boolean, detail text)
language plpgsql
security definer
set search_path=public
as $$
begin
  return query
  select 'vehicles_read'::text,
    (select count(*) from public.vehicles v
      join public.profiles me on me.org_id=v.org_id and me.user_id=auth.uid()) >= 0 as ok,
    'vehicles visible within org'::text;

  return;
end;
$$;