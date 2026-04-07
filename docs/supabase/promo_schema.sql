-- docs/supabase/promo_schema.sql
-- Promo Codes + QR Checkout — schema (MVP)
-- Apply in Supabase SQL editor or CLI.

-- Enums
create type promo_discount_type as enum ('percent','amount');
create type promo_redemption_status as enum ('pending','approved','declined');

-- Base promotions table (org-scoped)
create table if not exists promotions (
  id bigserial primary key,
  org_id uuid not null references orgs(org_id) on delete cascade,
  title text not null,
  description text,
  type promo_discount_type not null default 'amount',
  value_cents int not null check (value_cents >= 0),
  start_at timestamptz not null,
  end_at timestamptz not null,
  sku_scope jsonb default '{}'::jsonb,
  min_spend_cents int default 0 check (min_spend_cents >= 0),
  per_user_limit int default null check (per_user_limit is null or per_user_limit >= 0),
  per_day_limit int default null check (per_day_limit is null or per_day_limit >= 0),
  global_cap int default null check (global_cap is null or global_cap >= 0),
  hours jsonb default null,
  channels text[] not null default '{QR,code}',
  locations text[] default null, -- optional whitelist of location_id strings
  is_active boolean not null default true,
  poster_qr_url text default null,
  pos_shortcode text unique,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create index if not exists idx_promotions_org_active on promotions(org_id, is_active);
create index if not exists idx_promotions_window on promotions(start_at, end_at);

-- promo_codes: static codes tied to a promotion
create table if not exists promo_codes (
  id bigserial primary key,
  promo_id bigint not null references promotions(id) on delete cascade,
  code text not null,
  max_uses int default null check (max_uses is null or max_uses >= 0),
  used_count int not null default 0 check (used_count >= 0),
  expires_at timestamptz default null,
  is_active boolean not null default true,
  unique (promo_id, code)
);
create index if not exists idx_promo_codes_active on promo_codes(promo_id, is_active);

-- QR nonce: ephemeral one-time token issuance
create table if not exists promo_qr_nonce (
  nonce uuid primary key default gen_random_uuid(),
  promo_id bigint not null references promotions(id) on delete cascade,
  user_id uuid not null,
  expires_at timestamptz not null,
  used_at timestamptz default null,
  device_hash text default null,
  created_at timestamptz not null default now()
);
create index if not exists idx_promo_qr_nonce_user on promo_qr_nonce(user_id);
create index if not exists idx_promo_qr_nonce_exp on promo_qr_nonce(expires_at);

-- Redemptions: writes by server after verification
create table if not exists promo_redemptions (
  id bigserial primary key,
  promo_id bigint not null references promotions(id) on delete cascade,
  user_id uuid,
  location_id uuid,
  amount_cents int not null,
  discount_cents int not null,
  status promo_redemption_status not null,
  reason text,
  cashier_id text,
  device_hash text,
  pos_ref text,
  created_at timestamptz not null default now()
);
create index if not exists idx_redemptions_promo_time on promo_redemptions(promo_id, created_at desc);
create index if not exists idx_redemptions_user_time on promo_redemptions(user_id, created_at desc);

-- Loyalty wallet: saved promos
create table if not exists loyalty_wallet (
  user_id uuid not null,
  promo_id bigint not null references promotions(id) on delete cascade,
  saved_at timestamptz not null default now(),
  primary key (user_id, promo_id)
);

-- Optional: promo audit (lightweight)
create table if not exists promo_audit (
  id bigserial primary key,
  promo_id bigint not null references promotions(id) on delete cascade,
  actor_user_id uuid,
  action text not null, -- created|updated|status_change|deleted
  diff jsonb,
  created_at timestamptz not null default now()
);

-- Helper views (optional minimal analytics)
create or replace view v_promo_usage as
select p.id as promo_id,
       p.title,
       p.org_id,
       count(r.*) filter (where r.status = 'approved') as approvals,
       count(r.*) filter (where r.status = 'declined') as declines,
       coalesce(sum(r.discount_cents) filter (where r.status = 'approved'), 0) as total_discount_cents,
       min(r.created_at) as first_redeemed_at,
       max(r.created_at) as last_redeemed_at
from promotions p
left join promo_redemptions r on r.promo_id = p.id
group by p.id, p.title, p.org_id;
