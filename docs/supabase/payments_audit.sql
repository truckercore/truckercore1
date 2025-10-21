-- docs/supabase/payments_audit.sql
-- Payments audit schema (Stripe idempotency logging). Idempotent and safe to re-run.

create extension if not exists pgcrypto;

create table if not exists public.payments_audit (
  id uuid primary key default gen_random_uuid(),
  org_id uuid not null,
  processor text not null default 'stripe',
  operation text not null,              -- e.g., 'invoice.pay', 'payment_intent.confirm'
  idempotency_key text not null,
  processor_id text null,               -- e.g., payment_intent id, charge id
  status text not null check (status in ('success','retry','failed')),
  attempt_no int not null default 1,
  final_outcome text null,              -- 'succeeded' | 'requires_action' | 'canceled' | ...
  amount_cents int null,
  currency text null,
  error_code text null,
  error_message text null,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);
create index if not exists idx_payments_audit_org_time on public.payments_audit (org_id, created_at desc);
create index if not exists idx_payments_audit_key on public.payments_audit (idempotency_key);

alter table public.payments_audit enable row level security;
create or replace function public.jwt_claim(claim text)
returns text stable language sql as $$ select coalesce(current_setting('request.jwt.claims', true)::json->>claim, '') $$;

create policy if not exists payments_audit_read_org on public.payments_audit
  for select to authenticated using (org_id::text = public.jwt_claim('app_org_id'));
revoke insert, update, delete on public.payments_audit from authenticated;
