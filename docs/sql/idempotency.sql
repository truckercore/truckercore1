-- Tender quotes
alter table if exists public.tender_quotes
  add column if not exists idempotency_key text;
create unique index if not exists uq_tender_quotes_idem
  on public.tender_quotes(tender_id, bidder_org_id, idempotency_key)
  where idempotency_key is not null;

-- Invoices
alter table if exists public.invoices
  add column if not exists idempotency_key text;
create unique index if not exists uq_invoices_idem
  on public.invoices(org_id, idempotency_key)
  where idempotency_key is not null;
