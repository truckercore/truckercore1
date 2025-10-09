-- referral tracking events
create table if not exists public.referral_events (
  id uuid primary key default gen_random_uuid(),
  org_id uuid not null,
  integration_id uuid references public.integrations_catalog(id) on delete set null,
  event_type text not null check (event_type in ('viewed','connected','active_30d')),
  revenue_share_usd numeric(10,2) default 0,
  metadata jsonb default '{}'::jsonb,
  created_at timestamptz not null default now()
);
create index if not exists idx_referral_org_time on public.referral_events (org_id, created_at desc);
create index if not exists idx_referral_integration on public.referral_events (integration_id, event_type);
