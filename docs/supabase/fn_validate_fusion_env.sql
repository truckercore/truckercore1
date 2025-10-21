-- docs/supabase/fn_validate_fusion_env.sql
-- Helper to normalize app.* GUC settings and return clamped values with warnings.
-- Safe to run multiple times.

create or replace function public.fn_validate_fusion_env()
returns table (
  decay_half_life_min int,
  fusion_window_min int,
  operator_weight numeric,
  crowd_min_trust numeric,
  speed_window_min int,
  speed_tile_zoom int,
  warnings text[]
)
language plpgsql
security definer
as $$
declare
  w text[] := '{}';
  v_decay int := coalesce(nullif(current_setting('app.decay_half_life_min', true), '')::int, 30);
  v_window int := coalesce(nullif(current_setting('app.fusion_window_min', true), '')::int, 45);
  v_opw numeric := coalesce(nullif(current_setting('app.operator_weight', true), '')::numeric, 1.0);
  v_crowd numeric := coalesce(nullif(current_setting('app.crowd_min_trust', true), '')::numeric, 0.2);
  v_speed_win int := coalesce(nullif(current_setting('app.speed_window_min', true), '')::int, 15);
  v_zoom int := coalesce(nullif(current_setting('app.speed_tile_zoom', true), '')::int, 12);

begin
  -- clamps
  v_decay := greatest(5, least(240, v_decay));
  v_window := greatest(10, least(240, v_window));
  v_opw := greatest(0, least(2, v_opw));
  v_crowd := greatest(0, least(1, v_crowd));
  v_speed_win := greatest(5, least(120, v_speed_win));
  v_zoom := greatest(8, least(16, v_zoom));

  -- warn if missing raw settings
  if current_setting('app.decay_half_life_min', true) is null then
    w := w || 'DECAY_HALFLIFE_MIN not set; using default 30';
  end if;
  if current_setting('app.fusion_window_min', true) is null then
    w := w || 'FUSION_WINDOW_MIN not set; using default 45';
  end if;
  if current_setting('app.operator_weight', true) is null then
    w := w || 'OPERATOR_WEIGHT not set; using default 1.0';
  end if;
  if current_setting('app.crowd_min_trust', true) is null then
    w := w || 'CROWD_MIN_TRUST not set; using default 0.2';
  end if;
  if current_setting('app.speed_window_min', true) is null then
    w := w || 'SPEED_WINDOW_MIN not set; using default 15';
  end if;
  if current_setting('app.speed_tile_zoom', true) is null then
    w := w || 'SPEED_TILE_ZOOM not set; using default 12';
  end if;

  return query
  select v_decay, v_window, v_opw, v_crowd, v_speed_win, v_zoom, w;
end $$;

revoke all on function public.fn_validate_fusion_env() from public;
grant execute on function public.fn_validate_fusion_env() to authenticated, anon, service_role;
