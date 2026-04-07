create or replace function public.run_canary(org uuid)
returns jsonb
language plpgsql
security definer
set search_path=public
as $$
declare
  v_vehicle uuid;
  v_trip uuid;
  out_json jsonb;
begin
  -- create tiny vehicle
  insert into public.vehicles(org_id, vin, plate, make, model, year, odo_miles)
  values (org, 'VIN-CANARY', 'CAN-000', 'Test', 'Probe', 2025, 1)
  returning id into v_vehicle;

  -- write small IFTA trip
  insert into public.ifta_trips(
    org_id, driver_id, vehicle_id, started_at, ended_at, total_miles, state_miles
  )
  values (
    org,
    (select user_id from public.profiles where org_id = org limit 1),
    v_vehicle,
    now() - interval '30 minutes',
    now(),
    10.0,
    '{"TX":"10.0"}'
  )
  returning id into v_trip;

  -- read via view
  perform 1
  from public.ifta_quarterly
  where org_id = org
    and quarter = date_trunc('quarter', now())::date;

  -- cleanup (soft delete: keep vehicle for 1 min to catch async jobs)
  delete from public.ifta_trips where id = v_trip;

  out_json := jsonb_build_object('vehicle_id', v_vehicle, 'trip_id', v_trip, 'ok', true);
  return out_json;

exception when others then
  return jsonb_build_object('ok', false, 'error', sqlerrm);
end;
$$;