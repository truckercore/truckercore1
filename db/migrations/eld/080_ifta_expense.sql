begin;

create table if not exists public.fuel_receipts (
  id uuid primary key default gen_random_uuid(),
  driver_id uuid not null,
  org_id uuid not null,
  gallons numeric not null,
  price_per_gal numeric not null,
  location text,
  receipt_img_url text,
  purchased_at timestamptz not null
);

create or replace view public.v_ifta_quarterly as
select
  driver_id,
  date_trunc('quarter', purchased_at) as qtr,
  sum(gallons) as total_gal,
  sum(gallons * price_per_gal) as total_cost
from public.fuel_receipts
group by 1,2;

commit;