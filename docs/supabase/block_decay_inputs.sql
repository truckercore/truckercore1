-- docs/supabase/block_decay_inputs.sql
-- Decayed blocklist inputs/views over security_events to surface top blocked IPs.
-- Idempotent and safe to re-run.

-- Raw events table expected: public.security_events(ip inet, code text, severity int, occurred_at timestamptz)
-- Create views only (no table DDL here).

create or replace view public.v_block_decay_inputs as
select
  ip,
  code,
  severity,
  extract(epoch from (now() - occurred_at))/60.0 as age_min,
  30::int as half_life_min,
  power(0.5, (extract(epoch from (now() - occurred_at))/60.0) / 30.0) as decay_weight
from public.security_events
where code in ('auth_fail','abuse','rate_limit','waf_block');

create or replace view public.v_block_scores as
select
  ip,
  sum(severity * power(0.5, age_min/half_life_min)) as score,
  max(half_life_min) as half_life_min
from public.v_block_decay_inputs
group by ip
order by score desc;

create or replace view public.v_block_top as
select * from public.v_block_scores where score >= 5.0 order by score desc limit 100;
