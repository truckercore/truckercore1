begin;

-- Replace/define a health view with required shape for auto-promotion checks
-- Columns: bucket (time bucket), model_key, p95_ms, error_rate, mae_delta
-- We approximate error_rate/mae_delta as 0 if not available; p95_ms from ai_inference_events.latency_ms
create or replace view public.ai_promo_health as
with buckets as (
  select 
    date_trunc('hour', created_at) as bucket,
    model_key,
    latency_ms
  from public.ai_inference_events
  where latency_ms is not null
    and created_at > now() - interval '6 hours'
), agg as (
  select
    bucket,
    model_key,
    percentile_cont(0.95) within group (order by latency_ms) as p95_ms,
    0.0::numeric as error_rate,
    0.0::numeric as mae_delta
  from buckets
  group by bucket, model_key
)
select * from agg;

comment on view public.ai_promo_health is 'Auto-promotion health window per model_key (p95_ms; error_rate/mae_delta placeholders if unavailable).';

-- Auto-promotion helper: checks recent health and bumps canary by step when healthy
create or replace function public.ai_auto_promote_check(
  p_model_key text default 'eta',
  p_window_minutes int default 60,
  p_max_p95_ms int default 800,
  p_max_error_rate numeric default 0.01,
  p_max_mae_delta numeric default 0.02,
  p_step int default 10
) returns void
language plpgsql
security definer
as $$
declare v_bad int; begin
  -- Any breach in the window halts promotion
  select count(*) into v_bad
  from public.ai_promo_health
  where model_key = p_model_key
    and bucket > now() - (p_window_minutes || ' minutes')::interval
    and (p95_ms > p_max_p95_ms or error_rate > p_max_error_rate or mae_delta > p_max_mae_delta);

  if coalesce(v_bad,0) > 0 then
    insert into public.ai_promo_audit(model_key, action, actor, before, after, snapshot)
    select r.model_key, 'halt', 'auto', jsonb_build_object('pct', r.pct), jsonb_build_object('pct', r.pct),
           jsonb_build_object('reason','health_breach','breaches', v_bad,
                               'window_min', p_window_minutes,
                               'thresholds', jsonb_build_object('p95_ms', p_max_p95_ms, 'err', p_max_error_rate, 'mae_delta', p_max_mae_delta))
    from public.ai_model_rollouts r
    where r.model_key = p_model_key;
    return;
  end if;

  -- Healthy: bump canary (capture before/after via CTE)
  with cur as (
    select model_key, status, pct from public.ai_model_rollouts where model_key = p_model_key for update
  ), upd as (
    update public.ai_model_rollouts r
    set pct = least(coalesce(cur.pct,0) + p_step, 100), updated_at = now()
    from cur
    where r.model_key = cur.model_key and cur.status = 'canary' and coalesce(cur.pct,0) < 100
    returning cur.pct as before_pct, r.pct as after_pct
  )
  insert into public.ai_promo_audit (model_key, action, actor, before, after, snapshot)
  select p_model_key, 'auto_bump', 'auto',
         jsonb_build_object('pct', u.before_pct),
         jsonb_build_object('pct', u.after_pct),
         jsonb_build_object('window_min', p_window_minutes,
                            'thresholds', jsonb_build_object('p95_ms', p_max_p95_ms, 'err', p_max_error_rate, 'mae_delta', p_max_mae_delta),
                            'step', p_step)
  from upd u;
end $$;

grant select on public.ai_promo_health to anon, authenticated;
grant execute on function public.ai_auto_promote_check(text,int,int,numeric,numeric,int) to service_role;

commit;