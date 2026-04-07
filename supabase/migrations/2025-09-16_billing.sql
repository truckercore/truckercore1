-- 2025-09-16_billing.sql
-- Stripe billing helpers: plan catalog, admin_set_plan, get_billing_profile
-- Idempotent migration; adjusts profiles table with required columns.

set search_path = public;

-- 1) Ensure profiles has required billing columns
alter table if exists public.profiles
  add column if not exists plan text default 'free',
  add column if not exists trial_ends_at timestamptz null,
  add column if not exists subscription_status text null,
  add column if not exists stripe_customer_id text null,
  add column if not exists stripe_subscription_id text null,
  add column if not exists current_period_end timestamptz null,
  add column if not exists updated_at timestamptz null;

-- 2) Catalog mapping Stripe price -> plan
create table if not exists public.plan_catalog (
  price_id text primary key,
  plan text not null check (plan in ('free','trial','pro','enterprise')),
  description text null,
  created_at timestamptz not null default now()
);

comment on table public.plan_catalog is 'Maps Stripe price_id to internal plan code';

-- 3) Admin function to set plan & subscription fields
create or replace function public.admin_set_plan(
  p_user_id uuid,
  p_plan text,
  p_trial_ends_at timestamptz default null,
  p_subscription_status text default null,
  p_stripe_customer_id text default null,
  p_stripe_subscription_id text default null,
  p_current_period_end timestamptz default null
)
returns void
language plpgsql
security definer
as $$
begin
  update public.profiles set
    plan = p_plan,
    trial_ends_at = p_trial_ends_at,
    subscription_status = p_subscription_status,
    stripe_customer_id = coalesce(p_stripe_customer_id, stripe_customer_id),
    stripe_subscription_id = p_stripe_subscription_id,
    current_period_end = p_current_period_end,
    updated_at = now()
  where user_id = p_user_id;
end;
$$;

grant execute on function public.admin_set_plan(uuid, text, timestamptz, text, text, text, timestamptz) to service_role; -- callable by service key

-- 4) Unified profile fetch for current user
create or replace function public.get_billing_profile()
returns jsonb
language plpgsql
stable
security definer
as $$
declare
  v_uid uuid := auth.uid();
  v_row record;
begin
  select plan, trial_ends_at, subscription_status, stripe_customer_id, stripe_subscription_id, current_period_end
    into v_row
  from public.profiles
  where user_id = v_uid;

  if not found then
    return '{}'::jsonb;
  end if;

  return jsonb_build_object(
    'plan', v_row.plan,
    'trial_ends_at', v_row.trial_ends_at,
    'subscription_status', v_row.subscription_status,
    'stripe_customer_id', v_row.stripe_customer_id,
    'stripe_subscription_id', v_row.stripe_subscription_id,
    'current_period_end', v_row.current_period_end
  );
end;
$$;

grant execute on function public.get_billing_profile() to authenticated, anon;
