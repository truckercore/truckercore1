create table if not exists public.secrets_metadata (
  key text primary key,          -- e.g., 'STRIPE_SECRET_KEY'
  rotated_at timestamptz not null default now(),
  owner text,
  notes text
);

create or replace function public.alert_on_stale_secrets(max_age_days int default 120)
returns void language sql security definer set search_path=public as $$
  insert into public.alert_outbox(key, payload)
  select 'secret_rotation_due', jsonb_build_object('key', s.key, 'rotated_at', s.rotated_at, 'max_age_days', max_age_days)
  from public.secrets_metadata s
  where s.rotated_at < now() - (max_age_days || ' days')::interval;
$$;
