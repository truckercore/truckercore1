begin;

-- Backfill RPC: generate synthetic or derived ROI rows for past N days
-- Writes with is_backfill = true and source = 'backfill_{method}' when not dryrun
create or replace function public.fn_roi_backfill(p_org_id uuid, p_days int, p_method text, p_dryrun bool)
returns jsonb
language plpgsql security definer
as $$
declare
  d int := greatest(1, least(coalesce(p_days, 30), 365));
  method text := coalesce(p_method, 'default');
  dry boolean := coalesce(p_dryrun, true);
  inserted int := 0;
  examined int := 0;
  day_start date;
  cents int;
  src text := 'backfill_' || method;
begin
  -- Iterate days back from today; simple heuristic uses existing rollups if present
  for i in 0..d-1 loop
    day_start := (current_date - i);
    examined := examined + 1;
    -- If there are no events for this day for the org, optionally insert a small baseline row (promo 0)
    if not exists (select 1 from public.ai_roi_events e where e.org_id = p_org_id and e.created_at >= day_start and e.created_at < day_start + 1) then
      cents := 0; -- neutral backfill; customize per method if desired
      if not dry then
        insert into public.ai_roi_events(org_id, event_type, amount_cents, rationale, source, is_backfill, attribution_method)
        values (p_org_id, 'fuel_savings', cents, jsonb_build_object('backfill', true, 'method', method), src, true, 'PSM_v0');
        inserted := inserted + 1;
      end if;
    end if;
  end loop;

  return jsonb_build_object('org_id', p_org_id, 'days_considered', d, 'rows_inserted', inserted, 'examined_days', examined, 'method', method, 'dryrun', dry);
end;
$$;

revoke all on function public.fn_roi_backfill(uuid,int,text,bool) from public;
grant execute on function public.fn_roi_backfill(uuid,int,text,bool) to service_role;

commit;
