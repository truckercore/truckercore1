-- docs/sql/gate_thresholds.sql
create table if not exists public.gate_thresholds(
  key text primary key,              -- 'slo.p95_ms','probe.fail.max','announce.max_audience'
  value_numeric numeric,
  value_text text,
  updated_at timestamptz default now()
);

insert into public.gate_thresholds(key,value_numeric) values
  ('slo.p95_ms', 1200),
  ('probe.fail.max', 0),
  ('announce.max_audience', 10000)
on conflict (key) do nothing;

create or replace view public.v_gate_thresholds as
select key, value_numeric as num, value_text as txt from public.gate_thresholds;
