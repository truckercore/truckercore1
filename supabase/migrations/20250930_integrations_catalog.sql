-- Integration registry tables and seeds
create table if not exists public.integrations_catalog (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  slug text unique not null,
  category text not null check (category in ('eld','tms','insurance','compliance','broker')),
  logo_url text,
  description text,
  revenue_share_pct numeric(5,2) default 0,
  webhook_url text,
  active boolean not null default true,
  created_at timestamptz not null default now()
);

create table if not exists public.org_integrations (
  org_id uuid not null,
  integration_id uuid references public.integrations_catalog(id) on delete cascade,
  enabled boolean not null default true,
  config jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  primary key (org_id, integration_id)
);

alter table public.org_integrations enable row level security;
create policy if not exists org_integrations_read on public.org_integrations for select to authenticated
using (org_id::text = coalesce(current_setting('request.jwt.claims', true)::json->>'app_org_id',''));

-- Seed sample integrations
insert into public.integrations_catalog (name, slug, category, description, revenue_share_pct, active) values
('Samsara ELD', 'samsara', 'eld', 'Real-time HOS, location, and inspection data.', 10, true),
('Geotab ELD', 'geotab', 'eld', 'Fleet telematics and ELD compliance.', 10, true),
('Trimble TMS', 'trimble', 'tms', 'Integrated dispatch and load tracking.', 15, true),
('Next Insurance', 'next-insurance', 'insurance', 'Commercial truck insurance with API quoting.', 20, true),
('FMCSA Compliance Hub', 'fmcsa-hub', 'compliance', 'Automated CSA score tracking and alerts.', 0, true)
on conflict (slug) do nothing;
