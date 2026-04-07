begin;

create or replace function ai_auto_promote_check()
returns void
language plpgsql
security definer
as $$
declare
  rec record;
  cfg record;
  budget int;
  now_t time := (now() at time zone 'utc')::time; -- adjust TZ if needed
begin
  for rec in select * from ai_model_rollouts where strategy='canary' loop
    select * into cfg from ai_auto_promote_config where model_key = rec.model_key;
    if not found or cfg.enabled is false then continue; end if;

    -- blackout window (handles span across midnight)
    if cfg.blackout_start is not null and cfg.blackout_end is not null then
      if (cfg.blackout_start <= cfg.blackout_end and now_t between cfg.blackout_start and cfg.blackout_end)
         or (cfg.blackout_start > cfg.blackout_end and (now_t >= cfg.blackout_start or now_t <= cfg.blackout_end)) then
        continue;
      end if;
    end if;

    -- steps budget
    select steps_24h into budget from ai_auto_promote_budget where model_key = rec.model_key;
    if coalesce(budget,0) >= cfg.max_daily_steps then continue; end if;

    -- health/SLO gate example; replace with your existing checks
    if exists(
      select 1
      from ai_promo_health h
      where h.bucket > now() - (cfg.min_healthy_minutes||' minutes')::interval
        and h.p95_ms > 800
    ) then
      continue;
    end if;

    -- bump canary monotonically using your atomic RPC
    perform ai_promote_tx(
      rec.model_key,
      'increase_canary',
      null,
      least(100, coalesce(rec.canary_pct,0) + cfg.step_pct),
      'auto-stepper'
    );
  end loop;
end; $$;

commit;
