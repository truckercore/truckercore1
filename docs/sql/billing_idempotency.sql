create table if not exists public.stripe_events (
  id text primary key,     -- provider event id
  type text not null,
  received_at timestamptz default now(),
  processed_at timestamptz,
  status text check (status in ('pending','done','error')) default 'pending'
);
