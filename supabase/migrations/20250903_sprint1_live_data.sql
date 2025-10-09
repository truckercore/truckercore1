-- Sprint 1 live data scaffolding for Motive integration
-- Adjust to your schema as needed

create table if not exists provider_tokens (
  id uuid primary key default gen_random_uuid(),
  provider text not null,
  org_id text null,
  token text not null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create index if not exists provider_tokens_provider_idx on provider_tokens(provider);

create table if not exists motive_hos_staging (
  id bigserial primary key,
  driver_id text not null,
  start timestamptz not null,
  "end" timestamptz not null,
  status text not null,
  src_payload jsonb,
  ingested_at timestamptz not null default now()
);

-- Optional: simple view to summarize daily HOS by driver for UI panel
create or replace view motive_hos_daily_summary as
select driver_id,
       date_trunc('day', start) as day,
       sum(case when status='driving' then extract(epoch from (least("end", date_trunc('day', start) + interval '1 day') - greatest(start, date_trunc('day', start))))/3600.0 else 0 end) as driving_hours,
       sum(case when status='on_duty' then extract(epoch from (least("end", date_trunc('day', start) + interval '1 day') - greatest(start, date_trunc('day', start))))/3600.0 else 0 end) as on_duty_hours
from motive_hos_staging
group by 1,2;
