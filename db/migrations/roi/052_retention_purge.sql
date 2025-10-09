begin;

-- Retention helper: purge ai_roi_events older than 18 months (dry-run by default)
create or replace function public.fn_roi_retention_purge(p_dryrun boolean default true)
returns jsonb
language plpgsql
security definer
as $$
declare
  cutoff timestamptz := now() - interval '18 months';
  to_delete int;
  deleted int := 0;
begin
  select count(*) into to_delete from public.ai_roi_events where created_at < cutoff;
  if coalesce(p_dryrun, true) then
    return jsonb_build_object('dryrun', true, 'older_than', cutoff, 'rows', to_delete);
  end if;

  delete from public.ai_roi_events where created_at < cutoff;
  get diagnostics deleted = row_count;
  return jsonb_build_object('dryrun', false, 'older_than', cutoff, 'deleted', deleted);
end;$$;

revoke all on function public.fn_roi_retention_purge(boolean) from public;
grant execute on function public.fn_roi_retention_purge(boolean) to service_role;

commit;
