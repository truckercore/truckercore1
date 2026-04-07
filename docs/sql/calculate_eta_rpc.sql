-- ETA RPC boundary (service-friendly)
create or replace function calculate_eta(p_trip_id uuid)
returns jsonb
language plpgsql security definer set search_path=public as $$
declare
  v_org uuid := app_org_id();
  last jsonb;
begin
  select prediction into last
  from ml_predictions
  where org_id = v_org and kind='eta' and entity_id = p_trip_id
  order by predicted_at desc limit 1;

  if last is null then
    return jsonb_build_object('status','no_prediction','trip_id',p_trip_id);
  end if;

  return jsonb_build_object('status','ok','trip_id',p_trip_id,'prediction', last);
end $$;
