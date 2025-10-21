create table if not exists public.fx_locks (
  id uuid primary key default gen_random_uuid(),
  quote_id uuid not null,
  base text not null,
  counter text not null,
  rate_microunits bigint not null, -- e.g. 1.234567 -> 1234567
  locked_at timestamptz default now(),
  unique(quote_id)
);

create or replace view public.invoices_with_delta as
select i.id, i.total_cents, p.expected_cents,
       (i.total_cents - p.expected_cents) as delta_cents
from public.invoices i
join (
  select invoice_id, sum(qty * unit_price_cents) expected_cents
  from public.invoice_items
  group by invoice_id
) p on p.invoice_id = i.id;
