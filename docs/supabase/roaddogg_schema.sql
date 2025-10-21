-- RoadDogg Assistant schema (Owner-Operator focus)
-- Idempotent migration. Safe to run multiple times.
-- Requires: public.loads table exists.

create table if not exists public.roaddogg_queries (
  id uuid primary key default gen_random_uuid(),
  owner_op_id uuid not null,
  query_text text,
  filters jsonb,
  loads_returned uuid[] null,
  created_at timestamptz not null default now()
);
comment on table public.roaddogg_queries is 'RoadDogg queries submitted by owner-operators (for rate limits & analytics).';
create index if not exists idx_roaddogg_queries_owner on public.roaddogg_queries(owner_op_id);
create index if not exists idx_roaddogg_queries_created on public.roaddogg_queries(created_at);

alter table public.roaddogg_queries enable row level security;
-- Only the owner can read/insert their own query rows
drop policy if exists roaddogg_queries_select on public.roaddogg_queries;
create policy roaddogg_queries_select on public.roaddogg_queries
  for select using (owner_op_id = (select auth.uid()));

drop policy if exists roaddogg_queries_insert on public.roaddogg_queries;
create policy roaddogg_queries_insert on public.roaddogg_queries
  for insert with check (owner_op_id = (select auth.uid()));

-- Broker Requests (apply/request actions sent to brokers)
create table if not exists public.broker_requests (
  id uuid primary key default gen_random_uuid(),
  load_id uuid not null references public.loads(id) on delete cascade,
  broker_id uuid null,
  owner_op_id uuid not null,
  message text,
  status text not null default 'requested', -- requested | approved | rejected | canceled
  created_at timestamptz not null default now()
);
comment on table public.broker_requests is 'Requests from owner-operators to brokers regarding specific loads.';
create index if not exists idx_broker_requests_owner on public.broker_requests(owner_op_id);
create index if not exists idx_broker_requests_broker on public.broker_requests(broker_id);
create index if not exists idx_broker_requests_load on public.broker_requests(load_id);

alter table public.broker_requests enable row level security;
-- Owner-operator can read their own requests
drop policy if exists broker_requests_owner_select on public.broker_requests;
create policy broker_requests_owner_select on public.broker_requests
  for select using (owner_op_id = (select auth.uid()));
-- Owner-operator can insert their own requests
drop policy if exists broker_requests_owner_insert on public.broker_requests;
create policy broker_requests_owner_insert on public.broker_requests
  for insert with check (owner_op_id = (select auth.uid()));
-- Broker can read requests addressed to them (if broker_id is set)
drop policy if exists broker_requests_broker_select on public.broker_requests;
create policy broker_requests_broker_select on public.broker_requests
  for select using (broker_id is not null and broker_id = (select auth.uid()));

-- Optional: status updates by broker or owner could be added later with separate policies.
