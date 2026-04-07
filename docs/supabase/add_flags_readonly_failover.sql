-- Seed or upsert feature flags for DR/BCP modes
-- Table expected: feature_flags(key text primary key, enabled boolean default false, description text, cohort text null)

insert into feature_flags(key, enabled, description)
values
  ('read_only_mode', false, 'When true, app operates in read-only: queue writes to outbox and show banner.'),
  ('failover_mode', false, 'When true, app routes reads to replica and queues writes; show Degraded—Failover banner.')
on conflict (key) do update set
  description = excluded.description;
