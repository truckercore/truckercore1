-- docs/supabase/promo_functions.sql
-- Helper functions and secured RPCs for Promo system.

-- Forecast usage counts for a user and promo
create or replace function fn_promo_usage_forecast(
  p_promo_id bigint,
  p_user_id uuid,
  p_day_start timestamptz
) returns table(user_total int, user_day int, global_total int) language sql stable as $$
  select
    (select count(*) from promo_redemptions r where r.promo_id = p_promo_id and r.user_id = p_user_id) as user_total,
    (select count(*) from promo_redemptions r where r.promo_id = p_promo_id and r.user_id = p_user_id and r.created_at >= p_day_start) as user_day,
    (select count(*) from promo_redemptions r where r.promo_id = p_promo_id) as global_total
$$;

-- Compute discount (server-side mirror) — optional utility
create or replace function fn_promo_compute_discount(
  p_type text,
  p_value_cents int,
  p_subtotal_cents int
) returns int language sql immutable as $$
  select case
    when p_type = 'percent' then floor((p_subtotal_cents * p_value_cents) / 10000.0)::int
    else least(p_value_cents, p_subtotal_cents)
  end
$$;

-- Operator-only redemption status update (secured by service role in Edge)
create or replace function rpc_operator_update_redemption_status(
  p_redemption_id bigint,
  p_status promo_redemption_status,
  p_reason text
) returns void language plpgsql security definer as $$
begin
  update promo_redemptions
     set status = p_status,
         reason = p_reason
   where id = p_redemption_id;
end;
$$;

-- Note: For strict atomicity on nonce consumption + redemption insert, consider a single plpgsql function
-- that verifies nonce validity, marks used_at, applies rule checks, and inserts the redemption within one tx.
-- The Edge implementation currently does best-effort sequencing suitable for MVP/dev.
