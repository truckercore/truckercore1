-- Supabase schema: user↔Stripe mapping + entitlements
-- Idempotent and safe to re-run

create table if not exists public.billing_profiles (
  user_id uuid primary key references auth.users(id) on delete cascade,
  org_id uuid null,
  stripe_customer_id text unique,
  stripe_subscription_id text,
  tier text not null default 'basic' check (tier in ('basic','premium','ai')),
  ai_enabled boolean not null default false,
  updated_at timestamptz not null default now()
);

-- touch_updated_at trigger (uses existing helper if present)
create or replace function public.touch_updated_at()
returns trigger language plpgsql as $$
begin new.updated_at = now(); return new; end $$;

drop trigger if exists billing_profiles_u on public.billing_profiles;
create trigger billing_profiles_u before update on public.billing_profiles
for each row execute function public.touch_updated_at();

alter table public.billing_profiles enable row level security;

-- RLS: user can read own row; writes via service-role (Edge Functions/webhooks)
create policy if not exists billing_profiles_me_ro on public.billing_profiles
for select to authenticated
using (auth.uid() = user_id);

-- No insert/update/delete for authenticated; service role only
revoke insert, update, delete on public.billing_profiles from authenticated;
grant select on public.billing_profiles to authenticated;
