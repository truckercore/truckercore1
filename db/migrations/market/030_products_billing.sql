begin;

create table if not exists data_products (
  key text primary key,
  description text not null
);

insert into data_products(key, description) values
('tier1_reports','Aggregated market trends and benchmarks'),
('tier2_predictive','Predictive pricing, demand forecasting, risk analytics'),
('tier3_insurance_api','Underwriting models & risk APIs')
on conflict (key) do nothing;

create table if not exists subscriptions (
  org_id uuid not null,
  product_key text not null references data_products(key),
  enabled boolean not null default false,
  monthly_quota int,
  started_at timestamptz not null default now(),
  primary key (org_id, product_key)
);

create table if not exists api_usage (
  id bigserial primary key,
  org_id uuid not null,
  product_key text not null,
  endpoint text not null,
  units int not null default 1,
  used_at timestamptz not null default now()
);
create index if not exists idx_api_usage_org_prod on api_usage(org_id, product_key, used_at desc);

create table if not exists fee_ledger (
  id bigserial primary key,
  org_id uuid not null,
  region_code text not null default 'US',
  fee_type text not null,
  ref_id uuid,
  amount_cents int not null,
  note text,
  created_at timestamptz not null default now()
);
create index if not exists idx_fee_ledger_org on fee_ledger(org_id, created_at desc);

commit;
