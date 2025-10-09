begin;

-- Raw GPS (assumes already exists); otherwise create minimal
create table if not exists gps_samples (
  id bigserial primary key,
  device_id text not null,
  lat double precision not null,
  lng double precision not null,
  speed_mps double precision,
  ts timestamptz not null default now()
);

-- Aggregated WebMercator speed tiles
create table if not exists tiles_speed_agg (
  z int not null,
  x int not null,
  y int not null,
  window_start timestamptz not null,
  count_samples int not null default 0,
  speed_p50 double precision,
  speed_p95 double precision,
  updated_at timestamptz not null default now(),
  primary key (z, x, y, window_start)
);

create index if not exists idx_tiles_speed_agg_key
  on tiles_speed_agg (z, x, y, window_start desc);

comment on table tiles_speed_agg is 'WebMercator speed aggregates over time windows';
comment on column tiles_speed_agg.speed_p50 is 'meters/second';
comment on column tiles_speed_agg.speed_p95 is 'meters/second';

-- RLS: public read of aggregates; deny raw samples (if desired)
alter table tiles_speed_agg enable row level security;
do $$
begin
  if not exists (
    select 1 from pg_policies
    where schemaname='public' and tablename='tiles_speed_agg' and policyname='tiles_public_read'
  ) then
    create policy tiles_public_read on tiles_speed_agg for select using (true);
  end if;
end $$;

alter table gps_samples enable row level security;
do $$
begin
  if not exists (
    select 1 from pg_policies
    where schemaname='public' and tablename='gps_samples' and policyname='gps_no_read'
  ) then
    create policy gps_no_read on gps_samples for select using (false);
  end if;
end $$;

commit;
