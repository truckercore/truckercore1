create table if not exists public.secrets_registry (
  key text primary key,
  rotated_at timestamptz not null,
  max_age_days int not null default 90
);
