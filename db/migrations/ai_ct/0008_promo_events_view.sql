begin;

-- Telemetry view over metrics_events for promotion control-plane
-- Exposes a structured table-like view expected by dashboards/queries
create or replace view public.promo_events as
select
  me.created_at as ts,
  'promoctl'::text as mod,
  (me.props->>'action')::text as action,
  (me.props->>'model_key')::text as model_key,
  nullif(me.props->>'old_state','') as old_state,
  nullif(me.props->>'new_state','') as new_state,
  nullif(me.props->>'to_version_id','') as to_version_id,
  nullif(me.props->>'candidate_version_id','') as candidate_version_id,
  nullif(me.props->>'idem_key','') as idem_key,
  (me.props->>'pct')::int as pct,
  (me.props->>'t_ms')::int as t_ms
from public.metrics_events me
where me.kind = 'ai_promote';

-- Convenience view for dashboards
create or replace view public.v_promo_events_last50 as
select * from public.promo_events order by ts desc limit 50;

comment on view public.promo_events is 'Promotion telemetry derived from metrics_events(kind=ai_promote)';
comment on view public.v_promo_events_last50 is 'Last 50 promotion actions (for dashboards)';

commit;
