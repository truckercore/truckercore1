-- Broker SLA stats (v1)
-- Location: docs/supabase/broker_sla_stats.sql
-- Aggregates reply time percentiles over the last 90 days per org+broker.
-- Assumes events table with offer and reply timestamps exists (e.g., broker_messages or offers).
-- This is a minimal placeholder that can be adapted to your schema.

-- Base table placeholder (if not exists) to avoid errors in early stages
create table if not exists public.broker_sla_stats (
  org_id uuid not null,
  broker_id text not null,
  p50_reply_min integer,
  p90_reply_min integer,
  samples integer not null default 0,
  refreshed_at timestamptz not null default now(),
  primary key (org_id, broker_id)
);

-- Example refresh function (no-op if you compute elsewhere)
create or replace function public.fn_refresh_broker_sla_stats()
returns void language plpgsql as $$
begin
  -- In production, compute percentiles from your offer/reply pairs over a 90d window
  -- and upsert into broker_sla_stats. This placeholder keeps the pipeline intact.
  update public.broker_sla_stats set refreshed_at = now();
end;$$;
