create or replace function award_quote_and_invoice(p_quote_id uuid, p_idempotency_key text)
returns uuid
language plpgsql
security definer
set search_path=public
as $$
declare
  v_tender tenders%rowtype;
  v_quote tender_quotes%rowtype;
  v_invoice_id uuid;
  v_org uuid; -- shipper org (billed party), adjust if your model differs
begin
  -- lock quote & tender
  select * into v_quote from tender_quotes where id = p_quote_id for update;
  if not found then raise exception 'Quote not found'; end if;

  select * into v_tender from tenders where id = v_quote.tender_id for update;
  if v_tender.status not in ('quoted','open') then
    raise exception 'Tender not in a quotable state: %', v_tender.status;
  end if;

  -- accept one, decline others
  update tender_quotes set status = 'accepted' where id = p_quote_id;
  update tender_quotes set status = 'declined' where tender_id = v_quote.tender_id and id <> p_quote_id;

  -- move tender to awarded
  update tenders set status = 'awarded' where id = v_quote.tender_id;

  -- idempotent invoice creation
  v_org := v_tender.shipper_org_id;

  select id into v_invoice_id from invoices
  where org_id = v_org and idempotency_key = p_idempotency_key limit 1;

  if v_invoice_id is null then
    insert into invoices(org_id, number, currency, subtotal_cents, tax_cents, total_cents, status, idempotency_key)
    values (
      v_org,
      concat('INV-', to_char(now(), 'YYYYMMDDHH24MISS'), '-', substr(p_idempotency_key,1,6)),
      coalesce((select billing_currency from shipper_accounts where org_id = v_org), 'USD'),
      v_quote.price_cents, 0, v_quote.price_cents, 'open', p_idempotency_key
    )
    returning id into v_invoice_id;

    insert into invoice_items(invoice_id, description, qty, unit_price_cents)
    values (v_invoice_id, coalesce(v_tender.commodity,'Freight service'), 1, v_quote.price_cents);
  end if;

  return v_invoice_id;
end $$;
