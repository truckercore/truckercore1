create table if not exists fx_quotes (
  id uuid primary key default gen_random_uuid(),
  tender_id uuid references tenders(id) on delete cascade,
  bidder_org_id uuid references orgs(id) on delete cascade,
  base_currency text not null default 'USD',
  quote_currency text not null default 'USD',
  fx_rate numeric not null default 1.0,   -- locked at quote time
  created_at timestamptz default now(),
  unique (tender_id, bidder_org_id)
);
