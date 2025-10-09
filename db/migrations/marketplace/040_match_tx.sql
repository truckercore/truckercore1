begin;

-- Transactional bid acceptance: accept bid, reject competing bids, mark load matched, create transaction
-- Returns jsonb with ids and status
create or replace function public.fn_match_load(p_bid_id uuid, p_actor_org uuid)
returns jsonb
language plpgsql
security definer
as $$
declare
  v_bid record;
  v_load record;
  v_txn_id uuid;
  v_amount_cents int;
begin
  -- Load bid for update
  select * into v_bid from public.load_bids where id = p_bid_id for update;
  if not found then
    raise exception 'bid_not_found';
  end if;
  if v_bid.status <> 'pending' then
    raise exception 'bid_not_pending';
  end if;

  -- Load load row for update
  select * into v_load from public.loads where id = v_bid.load_id for update;
  if not found then
    raise exception 'load_not_found';
  end if;
  if v_load.status <> 'open' then
    raise exception 'load_not_open';
  end if;

  -- Optional: ensure actor org is either load org or bidder org
  if p_actor_org is not null and p_actor_org <> v_load.org_id and p_actor_org <> v_bid.bidder_org then
    raise exception 'forbidden_actor_org';
  end if;

  -- Accept the bid
  update public.load_bids set status = 'accepted' where id = v_bid.id;
  -- Reject other pending bids for this load
  update public.load_bids set status = 'rejected' where load_id = v_bid.load_id and id <> v_bid.id and status = 'pending';

  -- Mark load as matched
  update public.loads set status = 'matched' where id = v_bid.load_id;

  -- Create transaction (payer = poster org, payee = bidder org) in cents
  v_amount_cents := round(coalesce(v_bid.bid_price_usd, 0) * 100)::int;
  if v_amount_cents <= 0 then
    v_amount_cents := 1; -- minimal positive to satisfy constraint
  end if;

  insert into public.load_transactions(load_id, payer_org, payee_org, amount_cents, status)
  values (v_bid.load_id, v_load.org_id, v_bid.bidder_org, v_amount_cents, 'pending')
  returning id into v_txn_id;

  return jsonb_build_object(
    'ok', true,
    'load_id', v_bid.load_id,
    'accepted_bid_id', v_bid.id,
    'transaction_id', v_txn_id,
    'amount_cents', v_amount_cents
  );
end;
$$;

revoke all on function public.fn_match_load(uuid, uuid) from public;
grant execute on function public.fn_match_load(uuid, uuid) to service_role;

commit;
