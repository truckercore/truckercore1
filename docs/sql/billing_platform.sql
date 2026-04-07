-- =============================================================
-- Billing Platform (Catalog, Tenancy, RLS, RPCs, Views)
-- Safe to re-run (idempotent)
-- =============================================================

-- Helpers
create or replace function public.current_org_id() returns uuid
language sql stable as $$ select nullif(auth.jwt()->>'app_org_id','')::uuid $$;
create or replace function public.current_user_id() returns uuid
language sql stable as $$ select auth.uid() $$;
create or replace function public.is_admin() returns boolean
language sql stable as $$ select coalesce(auth.jwt()->>'app_role' in ('owner','admin','fleet_admin'), false) $$;

-- 1) Catalog
create table if not exists public.billing_products(
  id text primary key,
  name text not null,
  description text,
  is_active boolean not null default true,
  created_at timestamptz default now()
);
create table if not exists public.billing_prices(
  id text primary key,
  product_id text not null references public.billing_products(id) on delete cascade,
  nickname text,
  currency text not null default 'usd',
  unit_amount_cents int not null,
  billing_interval text not null check (billing_interval in ('month','year')),
  is_metered boolean not null default false,
  is_active boolean not null default true,
  created_at timestamptz default now()
);
create table if not exists public.billing_features(
  code text primary key,
  description text
);
create table if not exists public.plan_feature_map(
  product_id text references public.billing_products(id) on delete cascade,
  feature_code text references public.billing_features(code) on delete cascade,
  primary key (product_id, feature_code)
);
create index if not exists idx_prices_product on public.billing_prices(product_id);

insert into public.billing_products(id,name,description) values
 ('prod_prem_loc','Premium per-location','Premium plan per location'),
 ('prod_enterprise','Enterprise','Enterprise custom'),
 ('prod_addons','Add-ons','SSO/SCIM/Exec Analytics') on conflict do nothing;
insert into public.billing_prices(id,product_id,nickname,currency,unit_amount_cents,billing_interval,is_metered,is_active) values
 ('price_prem_199','prod_prem_loc','Premium per-location 199','usd',19900,'month',false,true),
 ('price_prem_349','prod_prem_loc','Premium per-location 349','usd',34900,'month',false,true),
 ('price_prem_499','prod_prem_loc','Premium per-location 499','usd',49900,'month',false,true),
 ('price_enterprise_custom','prod_enterprise','Enterprise custom','usd',0,'month',false,true),
 ('price_addon_sso','prod_addons','SSO/SCIM Add-on','usd',9900,'month',false,true),
 ('price_addon_exec','prod_addons','Exec Analytics Add-on','usd',14900,'month',false,true) on conflict do nothing;
insert into public.billing_features(code,description) values
 ('premium','Premium core features'),
 ('sso','Single Sign-On'),
 ('scim','User provisioning (SCIM)'),
 ('exec_analytics','Executive analytics dashboard') on conflict do nothing;
insert into public.plan_feature_map(product_id,feature_code) values
 ('prod_prem_loc','premium'),
 ('prod_enterprise','premium'),
 ('prod_addons','sso'),('prod_addons','scim'),('prod_addons','exec_analytics') on conflict do nothing;

-- 2) Tenancy & lifecycle
create table if not exists public.org_billing (
  org_id uuid primary key,
  stripe_customer_id text unique,
  billing_email text,
  tax_id text,
  business_name text,
  country text,
  created_at timestamptz default now()
);
create table if not exists public.org_subscriptions (
  id text primary key,
  org_id uuid not null references public.org_billing(org_id) on delete cascade,
  product_id text not null references public.billing_products(id),
  price_id text not null references public.billing_prices(id),
  status text not null,
  quantity int not null default 1,
  current_period_start timestamptz,
  current_period_end timestamptz,
  cancel_at_period_end boolean default false,
  canceled_at timestamptz,
  trial_end timestamptz,
  created_at timestamptz default now()
);
create index if not exists idx_subs_org on public.org_subscriptions(org_id);
create index if not exists idx_subs_status on public.org_subscriptions(status);
create table if not exists public.org_subscription_items (
  id text primary key,
  subscription_id text references public.org_subscriptions(id) on delete cascade,
  price_id text not null references public.billing_prices(id),
  quantity int not null default 1
);
create index if not exists idx_sub_items_sub on public.org_subscription_items(subscription_id);
create table if not exists public.billable_locations (
  id uuid primary key default gen_random_uuid(),
  org_id uuid not null,
  location_id uuid not null,
  effective_from date not null default current_date,
  effective_to date,
  active boolean generated always as (effective_to is null or effective_to >= current_date) stored
);
create index if not exists idx_billable_locations_org_active on public.billable_locations(org_id, active);
create index if not exists idx_billable_locations_org_date on public.billable_locations(org_id, effective_from, effective_to);
create table if not exists public.org_dunning (
  org_id uuid primary key,
  state text not null default 'ok',
  last_invoice_id text,
  attempt_count int not null default 0,
  next_attempt_at timestamptz,
  updated_at timestamptz default now()
);
create table if not exists public.stripe_events_processed (
  id text primary key,
  received_at timestamptz default now()
);

-- RLS
alter table public.org_billing            enable row level security;
alter table public.org_subscriptions      enable row level security;
alter table public.org_subscription_items enable row level security;
alter table public.billable_locations     enable row level security;
alter table public.org_dunning            enable row level security;

create policy if not exists org_billing_rw on public.org_billing
  for all using (org_id = public.current_org_id()) with check (org_id = public.current_org_id());
create policy if not exists subs_ro on public.org_subscriptions
  for select using (org_id = public.current_org_id());
create policy if not exists subs_items_ro on public.org_subscription_items
  for select using (
    exists(select 1 from public.org_subscriptions s where s.id = public.org_subscription_items.subscription_id and s.org_id = public.current_org_id())
  );
create policy if not exists billloc_rw on public.billable_locations
  for all using (org_id = public.current_org_id()) with check (org_id = public.current_org_id());
create policy if not exists dunning_ro on public.org_dunning
  for select using (org_id = public.current_org_id());
create policy if not exists dunning_upd on public.org_dunning
  for update using (org_id = public.current_org_id());

-- Utility views
create or replace view public.v_org_location_seats as
select org_id, count(*) filter (where active) as seats
from public.billable_locations group by org_id;
create or replace view public.v_org_entitlements as
with active_subs as (
  select org_id, product_id, price_id, status
  from public.org_subscriptions
  where status in ('trialing','active') and (cancel_at_period_end=false or current_period_end>=now())
)
select s.org_id, f.feature_code
from active_subs s
join public.plan_feature_map pf on pf.product_id = s.product_id
join public.billing_features f on f.code = pf.feature_code
group by s.org_id, f.feature_code;

-- 3) Security/Taxes/Legal metadata
alter table public.org_billing
  add column if not exists tax_exempt boolean default false,
  add column if not exists billing_address jsonb,
  add column if not exists tos_accepted_at timestamptz,
  add column if not exists refund_policy_url text,
  add column if not exists cancel_policy_url text;

-- 4) RPCs
create or replace function public.billing_upsert_profile(
  p_billing_email text, p_business_name text, p_country text, p_tax_id text
) returns void language plpgsql security definer set search_path=public as $$
begin
  if not public.is_admin() then raise exception 'forbidden' using errcode='42501'; end if;
  insert into public.org_billing(org_id,billing_email,business_name,country,tax_id)
  values (public.current_org_id(),p_billing_email,p_business_name,p_country,p_tax_id)
  on conflict (org_id) do update set
    billing_email=excluded.billing_email,
    business_name=excluded.business_name,
    country=excluded.country,
    tax_id=excluded.tax_id;
end $$;

create or replace function public.billing_set_location_active(p_location uuid, p_active boolean)
returns void language plpgsql security definer set search_path=public as $$
begin
  if not public.is_admin() then raise exception 'forbidden' using errcode='42501'; end if;
  if p_active then
    insert into public.billable_locations(org_id,location_id,effective_from)
    values (public.current_org_id(), p_location, current_date)
    on conflict do nothing;
  else
    update public.billable_locations
      set effective_to = current_date - 1
    where org_id = public.current_org_id()
      and location_id = p_location
      and effective_to is null;
  end if;
end $$;

create or replace function public.billing_seat_count_today()
returns int language sql stable as $$
  select coalesce((select seats from public.v_org_location_seats where org_id=public.current_org_id()),0)
$$;

-- 7) Entitlements & grace (view)
create or replace view public.v_org_feature_flags as
select e.org_id,
       e.feature_code,
       (select state from public.org_dunning d where d.org_id=e.org_id) as dunning_state,
       case when (select state from public.org_dunning d where d.org_id=e.org_id) in ('suspended','downgraded') then false else true end as enabled_now
from public.v_org_entitlements e;

-- 8) Reporting views
create or replace view public.v_bi_mrr as
select org_id,
       sum(case when bp.billing_interval='month' then bp.unit_amount_cents * os.quantity
                when bp.billing_interval='year'  then (bp.unit_amount_cents/12) * os.quantity
                else 0 end) as mrr_cents
from public.org_subscriptions os
join public.billing_prices bp on bp.id=os.price_id
where os.status in ('trialing','active')
group by org_id;
create or replace view public.v_bi_arr as
select org_id,
       sum(case when bp.billing_interval='month' then bp.unit_amount_cents*12*os.quantity
                when bp.billing_interval='year'  then bp.unit_amount_cents*os.quantity
                else 0 end) as arr_cents
from public.org_subscriptions os
join public.billing_prices bp on bp.id=os.price_id
where os.status in ('trialing','active')
group by org_id;
create or replace view public.v_bi_dunning as
select d.org_id, d.state, d.attempt_count, d.next_attempt_at, d.last_invoice_id from public.org_dunning d;
create or replace view public.v_bi_churn_30d as
select org_id, count(*) as canceled_subs
from public.org_subscriptions
where status='canceled' and canceled_at > now() - interval '30 days'
group by org_id;
