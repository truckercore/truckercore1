-- docs/supabase/promo_rls.sql
-- Enable RLS and minimal policies for promo system (MVP).
-- Assumes profiles(user_id, org_id) exists and app_current_org_id()/app_roles() helpers from truck_stop_rls.sql.

alter table promotions enable row level security;
alter table promo_codes enable row level security;
alter table promo_qr_nonce enable row level security;
alter table promo_redemptions enable row level security;
alter table loyalty_wallet enable row level security;
alter table promo_audit enable row level security;

-- Promotions: drivers can read active promos (public-ish via Edge), operators manage within org
create policy promotions_select_org on promotions for select using (
  (app_current_org_id() is not null and org_id = app_current_org_id()) or is_active
);
create policy promotions_insert_org on promotions for insert with check (
  org_id = app_current_org_id()
);
create policy promotions_update_org on promotions for update using (
  org_id = app_current_org_id()
) with check (org_id = app_current_org_id());

-- Promo codes: read within org (operators); not directly by drivers (Edge mediates codes)
create policy promo_codes_select_org on promo_codes for select using (
  exists(select 1 from promotions p where p.id = promo_codes.promo_id and p.org_id = app_current_org_id())
);
create policy promo_codes_cud_org on promo_codes for all using (
  exists(select 1 from promotions p where p.id = promo_codes.promo_id and p.org_id = app_current_org_id())
) with check (
  exists(select 1 from promotions p where p.id = promo_codes.promo_id and p.org_id = app_current_org_id())
);

-- Loyalty wallet: user self insert/select/delete
create policy wallet_rw_self on loyalty_wallet for all using (auth.uid() = user_id) with check (auth.uid() = user_id);

-- QR nonce: deny direct access to normal clients; managed via service role in Edge
create policy qr_none_select_none on promo_qr_nonce for select using (false);
create policy qr_none_modify_none on promo_qr_nonce for all using (false) with check (false);

-- Redemptions: deny direct writes; inserted by service role only. Operators can read by org/location.
create policy redemptions_select_org on promo_redemptions for select using (
  exists(
    select 1 from locations l
    where l.location_id = promo_redemptions.location_id
      and l.org_id = app_current_org_id()
  )
);
create policy redemptions_modify_none on promo_redemptions for all using (false) with check (false);

-- Audit table: read in org; writes by service role only
create policy promo_audit_select_org on promo_audit for select using (
  exists(select 1 from promotions p where p.id = promo_audit.promo_id and p.org_id = app_current_org_id())
);
create policy promo_audit_modify_none on promo_audit for all using (false) with check (false);
