-- ============================================================
-- MIGRATION: Alert Engine Hardening (Feedback, Clustering, State)
-- ============================================================

-- 1. AI Feedback Loop
create table if not exists alert_ai_feedback (
  id uuid primary key default gen_random_uuid(),
  alert_id uuid references alert_events(id) on delete cascade,
  action_taken text not null, -- e.g. 'rerouted', 'ignored', 'dismissed'
  was_helpful boolean not null,
  resolution_time_ms bigint,
  dispatcher_note text,
  actor_id uuid references profiles(id),
  created_at timestamptz default now()
);

-- 2. Alert Clusters
create table if not exists alert_clusters (
  id uuid primary key default gen_random_uuid(),
  org_id uuid not null references organizations(id),
  name text not null,
  label text not null,
  description text,
  driver_id uuid references profiles(id),
  load_id uuid references loads(id),
  status text not null default 'open',
  created_at timestamptz default now(),
  updated_at timestamptz default now()
);

-- 3. Enhance alert_events with hardening fields
alter table alert_events
  add column if not exists fingerprint text,
  add column if not exists priority_score int default 0,
  add column if not exists upgrade_count int default 0,
  add column if not exists transition_history jsonb default '[]'::jsonb,
  add column if not exists cluster_id uuid references alert_clusters(id),
  add column if not exists escalated_at timestamptz,
  add column if not exists current_escalation_level int default 0,
  add column if not exists escalation_history jsonb default '[]'::jsonb,
  add column if not exists snoozed_until timestamptz,
  add column if not exists dismissed_at timestamptz,
  add column if not exists ai_action_taken text,
  add column if not exists ai_was_helpful boolean,
  add column if not exists ai_resolution_time_ms bigint;

-- Add idempotency to signal events
alter table alert_signal_events
  add column if not exists idempotency_key text unique,
  add column if not exists processed_at timestamptz;

-- Indexes for performance
create index if not exists idx_alerts_fingerprint_status on alert_events (fingerprint) where status = 'open';
create index if not exists idx_alerts_priority on alert_events (priority_score desc, created_at asc);
create index if not exists idx_alerts_escalation on alert_events (status, auto_escalate, current_escalation_level) where status = 'open';

-- 4. KPI View for Alerts
create or replace view v_alert_kpis as
select
  org_id,
  count(*) filter (where status = 'open' and severity = 'critical') as open_critical,
  count(*) filter (where status = 'open' and severity = 'high') as open_high,
  count(*) filter (where status = 'open' and severity = 'medium') as open_medium,
  count(*) filter (where status = 'open' and severity = 'low') as open_low,
  count(*) filter (where created_at >= now() - interval '24 hours') as last_24h,
  avg(extract(epoch from (select (history->>'at')::timestamptz from jsonb_array_elements(transition_history) history where history->>'to' = 'acknowledged' limit 1) - created_at) / 60) as mean_time_to_acknowledge_min,
  avg(extract(epoch from resolved_at - created_at) / 60) as mean_time_to_resolve_min
from alert_events
group by org_id;

-- 5. Helper function to append escalation history
create or replace function append_escalation_history(alert_id uuid, new_level int, role text)
returns jsonb as $$
declare
  current_history jsonb;
begin
  select escalation_history into current_history from alert_events where id = alert_id;
  return coalesce(current_history, '[]'::jsonb) || jsonb_build_object(
    'level', new_level,
    'role', role,
    'escalated_at', now()
  );
end;
$$ language plpgsql security definer;

-- 6. Helper function to append transition history
create or replace function append_transition_history(p_alert_id uuid, p_entry jsonb)
returns jsonb as $$
declare
  current_history jsonb;
begin
  select transition_history into current_history from alert_events where id = p_alert_id;
  return coalesce(current_history, '[]'::jsonb) || p_entry;
end;
$$ language plpgsql security definer;
