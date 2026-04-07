-- 20250924_dispatch_finance_docs_eld.sql
-- Dispatch + Finance + Docs OCR + ELD foundations with metrics/RLS/RPCs
-- Safe to re-run (idempotent): uses IF NOT EXISTS, guarded constraints, and create or replace.

-- ===== Enums =====
create type public.load_status as enum ('draft','tendered','accepted','enroute_pickup','at_pickup','picked','enroute_delivery','at_delivery','delivered','exception','cancelled');
create type public.stop_kind   as enum ('pickup','delivery');
create type public.exception_code as enum ('late_pickup','late_delivery','detour','hos_violation','equipment_issue','docs_missing','other');
create type public.invoice_status as enum ('draft','sent','partial','paid','void');
create type public.payment_term  as enum ('net0','net15','net30','net45','net60');
create type public.eld_event_kind as enum ('position','hos_log','eld_event');

-- ===== Multi-tenant core =====
create table if not exists public.orgs(
  id uuid primary key default gen_random_uuid(),
  name text not null,
  created_at timestamptz not null default now()
);

create table if not exists public.entitlements(
  org_id uuid not null references public.orgs(id) on delete cascade,
  feature text not null,
  enabled boolean not null default true,
  primary key (org_id, feature)
);

create or replace view public._session_org as
select (current_setting('request.jwt.claims', true)::jsonb->>'app_org_id')::uuid as org_id;

-- ===== Metrics sink =====
create table if not exists public.metrics_events(
  id bigserial primary key,
  org_id uuid not null,
  actor_id uuid,
  entity_kind text not null,
  entity_id uuid,
  event_code text not null,
  prev_state jsonb,
  new_state jsonb,
  ts timestamptz not null default now(),
  tags jsonb,
  meta jsonb
);
create index if not exists metrics_org_ts_idx on public.metrics_events (org_id, ts desc);
create index if not exists metrics_event_code_ts_idx on public.metrics_events (event_code, ts desc);

-- ===== Dispatch schema =====
create table if not exists public.loads(
  id uuid primary key default gen_random_uuid(),
  org_id uuid not null references public.orgs(id) on delete cascade,
  ref_no text unique,
  status public.load_status not null default 'draft',
  customer_name text,
  equipment text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  sla_pickup_by timestamptz,
  sla_delivery_by timestamptz,
  tracking_token uuid unique default gen_random_uuid()
);
create index if not exists loads_org_status_idx on public.loads (org_id, status);
create index if not exists loads_sla_pickup_idx on public.loads (sla_pickup_by);
create index if not exists loads_sla_delivery_idx on public.loads (sla_delivery_by);

create table if not exists public.stops(
  id uuid primary key default gen_random_uuid(),
  load_id uuid not null references public.loads(id) on delete cascade,
  org_id uuid not null,
  seq int not null,
  kind public.stop_kind not null,
  name text,
  addr jsonb,
  appt_from timestamptz,
  appt_to timestamptz,
  eta timestamptz,
  ata timestamptz,
  lat double precision,
  lon double precision
);
create index if not exists stops_load_seq_idx on public.stops (load_id, seq);

create table if not exists public.assignments(
  id uuid primary key default gen_random_uuid(),
  org_id uuid not null,
  load_id uuid not null references public.loads(id) on delete cascade,
  driver_id uuid,
  tractor_id uuid,
  trailer_id uuid,
  assigned_by uuid,
  assigned_at timestamptz not null default now(),
  unique (org_id, load_id)
);

create table if not exists public.load_exceptions(
  id uuid primary key default gen_random_uuid(),
  org_id uuid not null,
  load_id uuid not null references public.loads(id) on delete cascade,
  code public.exception_code not null,
  message text,
  raised_at timestamptz not null default now(),
  resolved_at timestamptz
);
create index if not exists load_ex_org_time_idx on public.load_exceptions (org_id, raised_at desc);

create table if not exists public.outbound_messages(
  id bigserial primary key,
  org_id uuid not null,
  channel text not null check (channel in ('email','sms')),
  template text not null,
  to_addr text not null,
  payload jsonb not null,
  status text not null default 'queued',
  last_error text,
  created_at timestamptz not null default now(),
  sent_at timestamptz
);
create index if not exists om_status_idx on public.outbound_messages (status, created_at desc);

create table if not exists public.documents(
  id uuid primary key default gen_random_uuid(),
  org_id uuid not null,
  load_id uuid references public.loads(id) on delete cascade,
  kind text not null,
  storage_key text not null,
  uploaded_by uuid,
  uploaded_at timestamptz not null default now(),
  meta jsonb
);
create index if not exists documents_load_idx on public.documents (load_id, kind);

-- ===== Finance schema =====
create table if not exists public.rate_confirmations(
  id uuid primary key default gen_random_uuid(),
  org_id uuid not null,
  load_id uuid not null references public.loads(id) on delete cascade,
  amount_usd numeric(12,2) not null,
  fuel_surcharge_usd numeric(12,2) default 0,
  terms public.payment_term not null default 'net30',
  created_at timestamptz default now()
);
create unique index if not exists rc_org_load_unique on public.rate_confirmations (org_id, load_id);

create table if not exists public.invoices(
  id uuid primary key default gen_random_uuid(),
  org_id uuid not null,
  load_id uuid not null references public.loads(id) on delete cascade,
  invoice_no text unique,
  status public.invoice_status not null default 'draft',
  amount_due_usd numeric(12,2) not null,
  issued_at timestamptz,
  due_at timestamptz,
  paid_at timestamptz
);
create index if not exists invoices_org_status_idx on public.invoices (org_id, status, due_at);

create table if not exists public.payments(
  id uuid primary key default gen_random_uuid(),
  org_id uuid not null,
  invoice_id uuid not null references public.invoices(id) on delete cascade,
  amount_usd numeric(12,2) not null,
  received_at timestamptz not null default now(),
  method text
);
create index if not exists payments_invoice_idx on public.payments (invoice_id, received_at);

create table if not exists public.settlements(
  id uuid primary key default gen_random_uuid(),
  org_id uuid not null,
  load_id uuid not null references public.loads(id) on delete cascade,
  driver_id uuid,
  scheme text not null check (scheme in ('ppm','rev_split')),
  rate numeric(10,4) not null,
  miles numeric(10,2),
  calc_amount_usd numeric(12,2),
  settled_at timestamptz
);

-- ===== Docs OCR =====
create table if not exists public.ocr_jobs(
  id uuid primary key default gen_random_uuid(),
  org_id uuid not null,
  document_id uuid not null references public.documents(id) on delete cascade,
  status text not null check (status in ('queued','processing','needs_review','completed','failed')) default 'queued',
  model text,
  fields jsonb,
  validated_fields jsonb,
  created_at timestamptz default now(),
  updated_at timestamptz default now(),
  error text
);
create index if not exists ocr_jobs_org_status_idx on public.ocr_jobs (org_id, status, updated_at desc);

create table if not exists public.audit_log(
  id bigserial primary key,
  org_id uuid not null,
  entity_kind text not null,
  entity_id uuid,
  action text not null,
  actor_id uuid,
  ts timestamptz not null default now(),
  meta jsonb
);
create index if not exists audit_org_ts_idx on public.audit_log (org_id, ts desc);

-- ===== ELD/Telematics =====
create table if not exists public.eld_providers(
  id uuid primary key default gen_random_uuid(),
  code text unique not null,
  name text not null
);

create table if not exists public.positions(
  provider_id uuid not null references public.eld_providers(id),
  org_id uuid not null,
  device_id text not null,
  ts timestamptz not null,
  lat double precision not null,
  lon double precision not null,
  speed_kph numeric,
  meta jsonb,
  primary key (provider_id, device_id, ts)
);
create index if not exists positions_org_ts_idx on public.positions (org_id, ts desc);

create table if not exists public.hos_logs(
  provider_id uuid not null references public.eld_providers(id),
  org_id uuid not null,
  driver_id text not null,
  ts timestamptz not null,
  status text not null,
  meta jsonb,
  primary key (provider_id, driver_id, ts)
);

create table if not exists public.eld_events(
  provider_id uuid not null references public.eld_providers(id),
  org_id uuid not null,
  driver_id text not null,
  ts timestamptz not null,
  kind public.eld_event_kind not null,
  data jsonb,
  primary key (provider_id, driver_id, ts, kind)
);

-- ===== RLS enable + org policies =====
do $$ declare t record; begin
  for t in
    select unnest(ARRAY[
      'entitlements','metrics_events','loads','stops','assignments','load_exceptions',
      'outbound_messages','documents','rate_confirmations','invoices','payments','settlements',
      'ocr_jobs','audit_log','positions','hos_logs','eld_events'
    ]) as tbl
  loop
    execute format('alter table public.%I enable row level security;', t.tbl);
    execute format($pol$
      do $$ begin
        if not exists (select 1 from pg_policies where schemaname='public' and tablename='%I' and policyname='org_rw') then
          create policy org_rw on public.%I
            using (coalesce(org_id,(select org_id from public._session_org)) = (select org_id from public._session_org))
            with check (org_id = (select org_id from public._session_org));
        end if;
      end $$;
    $pol$, t.tbl, t.tbl);
  end loop;
end $$;

-- ===== Triggers → metrics_events =====
create or replace function public.fn_log_load_status_change()
returns trigger language plpgsql as $$
declare actor text := current_setting('request.jwt.claims', true);
begin
  if tg_op='UPDATE' and new.status is distinct from old.status then
    insert into public.metrics_events(org_id, actor_id, entity_kind, entity_id, event_code, prev_state, new_state, tags)
    values (new.org_id,
            nullif((actor::jsonb->>'sub'),''),
            'load', new.id, 'load.status.change',
            jsonb_build_object('status', old.status),
            jsonb_build_object('status', new.status),
            jsonb_build_object('ref_no', coalesce(new.ref_no,'')));
  end if;
  return new;
end $$;

drop trigger if exists trg_log_load_status_change on public.loads;
create trigger trg_log_load_status_change
after update on public.loads
for each row execute function public.fn_log_load_status_change();

-- ===== SLO / Metrics views =====
create or replace view public.v_dispatch_sla as
select l.org_id, l.id as load_id, l.status,
       l.sla_pickup_by, l.sla_delivery_by,
       greatest(extract(epoch from (now()-l.sla_pickup_by))/60,0) as pickup_minutes_over,
       greatest(extract(epoch from (now()-l.sla_delivery_by))/60,0) as delivery_minutes_over
from public.loads l;

create or replace view public.v_dispatch_board as
select org_id,
  count(*) filter (where status in ('tendered','accepted')) as ready,
  count(*) filter (where status in ('enroute_pickup','at_pickup')) as to_pickup,
  count(*) filter (where status in ('enroute_delivery','at_delivery')) as to_deliver,
  count(*) filter (where status='exception') as exceptions,
  count(*) filter (where now()>sla_pickup_by and status not in ('picked','enroute_delivery','at_delivery','delivered','cancelled')) as pickup_breach,
  count(*) filter (where now()>sla_delivery_by and status not in ('delivered','cancelled')) as delivery_breach
from public.loads group by org_id;

create or replace view public.v_exception_lane as
select e.org_id, e.load_id, e.code, e.message, e.raised_at
from public.load_exceptions e
where e.resolved_at is null;

create or replace view public.v_ar_aging as
select i.org_id, i.id as invoice_id, i.invoice_no, i.amount_due_usd,
  case
    when i.status='paid' then 'paid'
    when i.due_at is null then 'undated'
    when i.due_at >= now() then 'current'
    when now()-i.due_at <= interval '30 days' then '30'
    when now()-i.due_at <= interval '60 days' then '60'
    when now()-i.due_at <= interval '90 days' then '90'
    else '90+'
  end as bucket,
  i.status, i.due_at
from public.invoices i;

create or replace view public.v_ar_rollup as
select org_id, bucket, count(*) invoices, sum(amount_due_usd) total_due
from public.v_ar_aging group by org_id, bucket;

create or replace view public.v_ocr_metrics as
select org_id,
  count(*) filter (where status='completed' and created_at>=now()-interval '24 hours') as completed_24h,
  percentile_cont(0.95) within group (order by extract(epoch from (updated_at-created_at))*1000) as p95_ms
from public.ocr_jobs group by org_id;

create or replace view public.v_load_breadcrumb as
with last_pos as (
  select org_id, device_id, max(ts) as last_ts
  from public.positions group by 1,2
)
select p.org_id, p.device_id, p.ts, p.lat, p.lon
from public.positions p
join last_pos lp on lp.org_id=p.org_id and lp.device_id=p.device_id and lp.last_ts=p.ts;

create or replace view public.v_slo as
select
  (select count(*) from public.metrics_events me where me.event_code='load.status.change' and me.ts>=now()-interval '1 day') as load_status_changes_24h,
  (select count(*) from public.documents d where d.kind='pod' and d.uploaded_at>=now()-interval '1 day') as pod_uploads_24h;

-- ===== RPCs =====
create or replace function public.upsert_load(
  p_org uuid, p_ref text, p_status public.load_status default 'draft',
  p_sla_pickup timestamptz default null, p_sla_delivery timestamptz default null
) returns uuid
language plpgsql security definer as $$
declare v_id uuid;
begin
  select id into v_id from public.loads where org_id=p_org and ref_no=p_ref;
  if v_id is null then
    insert into public.loads (org_id, ref_no, status, sla_pickup_by, sla_delivery_by)
    values (p_org, p_ref, p_status, p_sla_pickup, p_sla_delivery)
    returning id into v_id;
  else
    update public.loads
       set status=p_status, sla_pickup_by=p_sla_pickup, sla_delivery_by=p_sla_delivery, updated_at=now()
     where id=v_id;
  end if;
  return v_id;
end $$;

revoke all on function public.upsert_load(uuid,text,public.load_status,timestamptz,timestamptz) from public, anon;
grant execute on function public.upsert_load(uuid,text,public.load_status,timestamptz,timestamptz) to authenticated;

create or replace function public.load_by_tracking_token(p_token uuid)
returns table(id uuid, status public.load_status, customer_name text, stops jsonb, docs jsonb)
language plpgsql stable as $$
begin
  return query
  select l.id, l.status, l.customer_name,
    (select jsonb_agg(jsonb_build_object('seq',s.seq,'kind',s.kind,'eta',s.eta,'ata',s.ata,'name',s.name))
       from public.stops s where s.load_id=l.id order by s.seq),
    (select jsonb_agg(jsonb_build_object('kind',d.kind,'uploaded_at',d.uploaded_at,'key',d.storage_key))
       from public.documents d where d.load_id=l.id and d.kind in ('pod','bol'))
  from public.loads l
  where l.tracking_token=p_token;
end $$;
grant execute on function public.load_by_tracking_token(uuid) to anon;

-- ===== Settlement calc helper =====
create or replace function public.calculate_settlement(p_scheme text, p_rate numeric, p_miles numeric, p_revenue numeric)
returns numeric language sql immutable as $$
  select case when p_scheme='ppm' then round(p_rate * p_miles / 100.0, 2)
              when p_scheme='rev_split' then round(coalesce(p_revenue,0) * p_rate, 2)
              else 0 end;
$$;

create or replace function public.fn_settlement_snapshot()
returns trigger language plpgsql as $$
begin
  new.calc_amount_usd := calculate_settlement(
    new.scheme, new.rate, new.miles,
    (select amount_usd from public.rate_confirmations where load_id=new.load_id limit 1)
  );
  return new;
end $$;

drop trigger if exists trg_settlement_snapshot on public.settlements;
create trigger trg_settlement_snapshot before insert or update on public.settlements
for each row execute function public.fn_settlement_snapshot();

-- ===== Storage RLS helper (for docs bucket paths like org/<org_id>/... ) =====
create or replace function public.storage_object_org_id(name text)
returns uuid language sql immutable as
$$ select nullif(regexp_replace(name, '^org/([0-9a-f-]+)/.*$', '\1'), name)::uuid; $$;
