create or replace function public.backfill_forecasts(
  p_route_id uuid,
  p_from timestamptz,
  p_to timestamptz
) returns int
language plpgsql
security definer
set search_path = public
as $$
declare
  inserted int := 0;
  t timestamptz;
begin
  t := date_trunc('hour', p_from);
  while t <= p_to loop
    if not exists (select 1 from public.forecasts f where f.route_id = p_route_id and f.ts = t) then
      insert into public.forecasts(route_id, ts, fuel_price, traffic_index, weather_code)
      values (p_route_id, t, null, null, null);
      inserted := inserted + 1;
    end if;
    t := t + interval '1 hour';
  end loop;
  return inserted;
end $$;
