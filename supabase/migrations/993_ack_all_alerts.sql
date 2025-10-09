-- 993_ack_all_alerts.sql
-- Admin utility to acknowledge all alerts for an org
create or replace function public.acknowledge_all_alerts_for_org(p_org_id uuid, p_actor uuid)
returns int
language plpgsql
security definer
set search_path = public
as $$
declare
  v_count int;
begin
  update public.alerts_events
  set acknowledged = true,
      acknowledged_by = p_actor,
      acknowledged_at = now()
  where org_id = p_org_id
    and acknowledged = false;

  get diagnostics v_count = row_count;
  return v_count;
end;
$$;
