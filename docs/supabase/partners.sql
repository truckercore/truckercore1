-- docs/supabase/partners.sql
-- Partner registry and monthly partner_payouts. Idempotent and safe to re-run.

create extension if not exists pgcrypto;

create table if not exists public.partners (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  kind text not null check (kind in ('truck_stop','factoring','ads')),
  rev_share_bps int not null check (rev_share_bps between 0 and 10000),
  meta jsonb not null default '{}'::jsonb,
  active boolean not null default true,
  created_at timestamptz not null default now()
);

create table if not exists public.partner_payouts (
  id uuid primary key default gen_random_uuid(),
  partner_id uuid not null references public.partners(id),
  org_id uuid null,
  period_month date not null,
  gross_cents bigint not null default 0,
  share_bps int not null,
  partner_amount_cents bigint not null,
  items jsonb not null default '[]'::jsonb,
  status text not null default 'pending' check (status in ('pending','approved','paid','failed')),
  created_at timestamptz not null default now()
);
create index if not exists idx_partner_payouts_partner_month on public.partner_payouts (partner_id, period_month);

-- RLS: allow authenticated to read own org rows if org_id is present; writes by service role only.
alter table public.partners enable row level security;
alter table public.partner_payouts enable row level security;

create or replace function public.jwt_claim(claim text)
returns text stable language sql as $$ select coalesce(current_setting('request.jwt.claims', true)::json->>claim, '') $$;

DO $$ BEGIN
  DROP POLICY IF EXISTS partner_payouts_read_org ON public.partner_payouts;
  CREATE POLICY partner_payouts_read_org ON public.partner_payouts
  FOR SELECT TO authenticated
  USING (org_id is null OR org_id::text = public.jwt_claim('app_org_id'));
EXCEPTION WHEN undefined_table THEN NULL; END $$;

revoke insert, update, delete on public.partner_payouts from authenticated;
