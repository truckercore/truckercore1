begin;

create or replace function fee_on_match()
returns trigger language plpgsql as $$
declare pct numeric := 0.01;
begin
  if new.event_type = 'matched' and new.price_usd is not null then
    insert into fee_ledger(org_id, region_code, fee_type, ref_id, amount_cents, note)
      values (new.org_id, new.region_code, 'freight_commission', new.load_id,
              round(new.price_usd * 100 * pct)::int, '1% commission');
  end if;
  return new;
end$$;

drop trigger if exists trg_fee_on_match on fact_load_events;
create trigger trg_fee_on_match
after insert on fact_load_events
for each row execute function fee_on_match();

commit;
