-- 990_alert_dedupe_escalation.sql

-- 1) Dedupe fingerprint (key + normalized payload) and TTL window to suppress repeats
alter table if not exists public.alert_outbox
  add column if not exists dedupe_key text,
  add column if not exists suppress_until timestamptz;

create index if not exists idx_alert_outbox_dedupe on public.alert_outbox(dedupe_key)
  where delivered_at is null;

-- Helper to normalize JSON → stable fingerprint
create or replace function public.json_sha256(j jsonb)
returns text language sql immutable as $$
  select encode(digest(coalesce(j::text,'')::bytea, 'sha256'), 'hex')
$$;

-- 2) Alert routing & escalation policy (simple)
create table if not exists public.alert_routes (
  key text primary key,                      -- e.g., 'slo_breach_1h'
  channel text not null default 'slack',     -- slack|email|pager
  dedupe_minutes int not null default 15,    -- suppress window for identical alerts
  escalate_after_minutes int not null default 30,
  enabled boolean not null default true,
  updated_at timestamptz not null default now()
);

insert into public.alert_routes(key, channel, dedupe_minutes, escalate_after_minutes, enabled)
values
  ('slo_breach_1h','slack',15,30,true),
  ('slo_breach_7d','email',60,0,true),
  ('fn_failures_gt_N','slack',15,30,true),
  ('rollup_freshness_missing','slack',30,60,true),
  ('secret_rotation_due','email',1440,0,true)
on conflict (key) do update
  set channel=excluded.channel,
      dedupe_minutes=excluded.dedupe_minutes,
      escalate_after_minutes=excluded.escalate_after_minutes,
      enabled=excluded.enabled,
      updated_at=now();

-- 3) Wrap insert → apply dedupe/suppression
create or replace function public.enqueue_alert(p_key text, p_payload jsonb)
returns void language plpgsql security definer set search_path=public as $$
declare
  route record;
  fp text;
  until_ts timestamptz;
begin
  select * into route from public.alert_routes where key=p_key and enabled limit 1;
  if not found then
    -- default behavior if route missing
    route := (p_key, 'slack', 15, 30, true, now());
  end if;

  fp := p_key || ':' || public.json_sha256(p_payload);
  until_ts := now() + (route.dedupe_minutes || ' minutes')::interval;

  -- If there is an undelivered alert with same dedupe_key still under suppression, skip
  if exists (
    select 1 from public.alert_outbox
    where dedupe_key = fp and delivered_at is null
      and (suppress_until is null or suppress_until > now())
  ) then return; end if;

  insert into public.alert_outbox(key, payload, dedupe_key, suppress_until)
  values (p_key, p_payload, fp, until_ts);
end;
$$;

-- 1.2 Use dedupe in existing emitters (no logic changes needed)
-- Replace raw inserts with enqueue_alert(...).

-- SLO breaches
create or replace function public.check_slo_alerts()
returns void language sql security definer set search_path=public as $$
  with breaches as (
    select 'slo_breach_1h'::text as key, jsonb_build_object(
      'window','1h','fn',b.fn,
      'availability', b.availability,
      'avail_target', b.avail_target,
      'p95_ms', b.p95_ms,
      'p95_target_ms', b.p95_target_ms
    ) as payload
    from public.slo_burn_1h b
    where b.availability < b.avail_target or b.p95_breach
    union all
    select 'slo_breach_7d', jsonb_build_object(
      'window','7d','fn',b.fn,
      'availability', b.availability,
      'avail_target', b.avail_target,
      'p95_ms', b.p95_ms,
      'p95_target_ms', b.p95_target_ms
    )
    from public.slo_burn_7d b
    where b.availability < b.avail_target or b.p95_breach
  )
  select public.enqueue_alert(key, payload) from breaches;
$$;

-- 2) Escalation for stale alerts
-- 2.1 SQL: create escalation rows if undelivered too long
create or replace function public.escalate_stale_alerts()
returns void language plpgsql security definer set search_path=public as $$
begin
  insert into public.alert_outbox(key, payload, dedupe_key)
  select a.key || '_escalated',
         jsonb_build_object(
           'original_id', a.id,
           'key', a.key,
           'payload', a.payload,
           'age_minutes', extract(epoch from (now()-a.created_at))/60
         ),
         a.dedupe_key || ':esc'
  from public.alert_outbox a
  join public.alert_routes r on r.key = a.key
  where a.delivered_at is null
    and r.escalate_after_minutes > 0
    and a.created_at <= now() - (r.escalate_after_minutes || ' minutes')::interval
    -- don’t double-escalate
    and not exists (
      select 1 from public.alert_outbox e
      where e.dedupe_key = a.dedupe_key || ':esc' and e.delivered_at is null
    );
end;
$$;