create table if not exists public.invoices (
  id uuid primary key default gen_random_uuid(),
  org_id uuid references public.orgs(id) on delete cascade,
  number text unique,
  currency text default 'USD',
  subtotal_cents bigint not null default 0,
  tax_cents bigint not null default 0,
  total_cents bigint not null default 0,
  status text default 'open' check (status in ('draft','open','due','paid','void')),
  stripe_session_id text,
  stripe_payment_intent text,
  created_at timestamptz default now(),
  due_at timestamptz
);

create table if not exists public.invoice_items (
  id uuid primary key default gen_random_uuid(),
  invoice_id uuid references public.invoices(id) on delete cascade,
  description text not null,
  qty int not null default 1,
  unit_price_cents bigint not null,
  amount_cents bigint generated always as (qty * unit_price_cents) stored
);

alter table public.invoices enable row level security;
alter table public.invoice_items enable row level security;

create policy inv_read_own on public.invoices
for select using ((auth.jwt()->>'app_org_id')::uuid = org_id);
create policy inv_write_own on public.invoices
for insert with check ((auth.jwt()->>'app_org_id')::uuid = org_id);

create policy inv_items_rw on public.invoice_items
for all using (exists(select 1 from public.invoices i where i.id = invoice_id and (auth.jwt()->>'app_org_id')::uuid = i.org_id))
with check (exists(select 1 from public.invoices i where i.id = invoice_id and (auth.jwt()->>'app_org_id')::uuid = i.org_id));
