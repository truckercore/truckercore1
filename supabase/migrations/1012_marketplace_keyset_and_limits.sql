-- 1012_marketplace_keyset_and_limits.sql
-- Keyset pagination RPCs for marketplace listings and bids; defensive and capped.

create schema if not exists api;

-- Open loads (marketplace_loads) by pickup_at desc, id desc
create or replace function api.marketplace_list_open_loads_keyset(
  p_limit int,
  p_cursor_pickup timestamptz default null,
  p_cursor_id uuid default null,
  p_origin_q text default null,
  p_dest_q text default null,
  p_equipment text default null
)
returns setof marketplace_loads
language sql stable
set search_path=public
as $$
  select * from public.marketplace_loads
  where status = 'open'
    and (p_origin_q is null or origin ilike ('%'||trim(p_origin_q)||'%'))
    and (p_dest_q   is null or destination ilike ('%'||trim(p_dest_q)||'%'))
    and (p_equipment is null or p_equipment='any' or equipment = trim(p_equipment))
    and (
      p_cursor_pickup is null
      or (pickup_at < p_cursor_pickup)
      or (pickup_at = p_cursor_pickup and id < p_cursor_id)
    )
  order by pickup_at desc, id desc
  limit greatest(1, least(coalesce(p_limit, 50), 200));
$$;

-- Offers/bids (marketplace_offers) by created_at desc, id desc for a given load or bidder
create or replace function api.marketplace_list_bids_keyset(
  p_limit int,
  p_cursor_created timestamptz default null,
  p_cursor_id uuid default null,
  p_load_id uuid default null,
  p_bidder_user_id uuid default null
)
returns setof marketplace_offers
language sql stable
set search_path=public
as $$
  select * from public.marketplace_offers
  where (p_load_id is null or load_id = p_load_id)
    and (p_bidder_user_id is null or bidder_user_id = p_bidder_user_id)
    and (
      p_cursor_created is null
      or (created_at < p_cursor_created)
      or (created_at = p_cursor_created and id < p_cursor_id)
    )
  order by created_at desc, id desc
  limit greatest(1, least(coalesce(p_limit, 50), 200));
$$;

-- Helpful indexes (safe if tables exist)
DO $$ BEGIN
  IF to_regclass('public.marketplace_loads') IS NOT NULL THEN
    EXECUTE 'create index if not exists idx_mkt_loads_pickup_id on public.marketplace_loads(pickup_at desc, id desc)';
    EXECUTE 'create index if not exists idx_mkt_loads_status on public.marketplace_loads(status)';
    EXECUTE 'create index if not exists idx_mkt_loads_origin on public.marketplace_loads(origin)';
    EXECUTE 'create index if not exists idx_mkt_loads_destination on public.marketplace_loads(destination)';
  END IF;
  IF to_regclass('public.marketplace_offers') IS NOT NULL THEN
    EXECUTE 'create index if not exists idx_mkt_offers_created_id on public.marketplace_offers(created_at desc, id desc)';
    EXECUTE 'create index if not exists idx_mkt_offers_load on public.marketplace_offers(load_id)';
    EXECUTE 'create index if not exists idx_mkt_offers_bidder on public.marketplace_offers(bidder_user_id)';
  END IF;
END $$;