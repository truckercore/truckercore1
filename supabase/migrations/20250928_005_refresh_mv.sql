-- SQL: refresh_materialized_view helper
create or replace function public.refresh_materialized_view(view_name text)
returns void
language plpgsql
security definer
as $$
begin
  execute format('refresh materialized view concurrently %I', view_name);
exception
  when feature_not_supported then
    -- fallback if not concurrently-capable
    execute format('refresh materialized view %I', view_name);
end;
$$;

revoke all on function public.refresh_materialized_view(text) from public;
grant execute on function public.refresh_materialized_view(text) to service_role;
