begin;

create table if not exists public.wellness_metrics (
  id uuid primary key default gen_random_uuid(),
  driver_id uuid not null,
  metric text not null check (metric in ('steps','sleep_hours','hydration','heart_rate')),
  value numeric not null,
  recorded_at timestamptz not null default now(),
  source text
);

create table if not exists public.wellness_rewards (
  id uuid primary key default gen_random_uuid(),
  driver_id uuid not null,
  reward_type text not null check (reward_type in ('discount','points')),
  points int not null default 0,
  awarded_at timestamptz not null default now(),
  reason text
);

commit;